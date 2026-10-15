import AppKit
import CryptoKit
import Foundation
import Network
import Security

struct GoogleTokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

@MainActor
final class GoogleAuth {
    private var listener: NWListener?
    private var continuation: CheckedContinuation<String, Error>?
    private var readyContinuation: CheckedContinuation<UInt16, Error>?
    private var timeout: Task<Void, Never>?
    private var state = ""
    private var receivedCallback = false
    private(set) var busy = false

    func authorize(clientID: String) async throws {
        guard !busy else { throw APIError.provider("authorization_in_progress") }
        guard clientID.hasSuffix(".apps.googleusercontent.com"), !clientID.contains(" ") else { throw APIError.provider("invalid_desktop_client_id") }
        busy = true; defer { busy = false; stop() }
        state = try randomURLSafe(); let verifier = try randomURLSafe()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let server = try NWListener(using: parameters)
        listener = server
        let port: UInt16 = try await withCheckedThrowingContinuation { ready in
            readyContinuation = ready
            server.stateUpdateHandler = { [weak self] status in
                Task { @MainActor in
                    guard let self, let pending = self.readyContinuation else { return }
                    switch status {
                    case .ready:
                        guard let port = server.port else { return }
                        self.readyContinuation = nil; pending.resume(returning: port.rawValue)
                    case .failed(let error):
                        self.readyContinuation = nil; pending.resume(throwing: error)
                    default: break
                    }
                }
            }
            server.start(queue: .main)
        }
        let redirect = "http://127.0.0.1:\(port)/oauth/callback"
        receivedCallback = false
        let code: String = try await withCheckedThrowingContinuation { result in
            continuation = result
            server.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .main)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { data, _, _, _ in
                    Task { @MainActor [weak self] in self?.receive(data: data, connection: connection) }
                }
            }
            var parts = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
            let fields = ["client_id": clientID, "redirect_uri": redirect, "response_type": "code",
                "scope": "https://www.googleapis.com/auth/calendar.events.readonly https://www.googleapis.com/auth/gmail.readonly",
                "access_type": "offline", "prompt": "consent", "state": state,
                "code_challenge": challenge, "code_challenge_method": "S256"]
            parts.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let url = parts.url, NSWorkspace.shared.open(url) else {
                finish(.failure(APIError.provider("browser_could_not_open"))); return
            }
            timeout = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 180_000_000_000)
                guard !Task.isCancelled else { return }
                self?.finish(.failure(APIError.provider("authorization_timed_out")))
            }
        }
        var fields = ["client_id": clientID, "code": code, "code_verifier": verifier,
                      "redirect_uri": redirect, "grant_type": "authorization_code"]
        if let secret = try SecretStore.get("google.clientSecret"), !secret.isEmpty { fields["client_secret"] = secret }
        let json = try await tokenRequest(fields)
        guard let access = json["access_token"] as? String, let refresh = json["refresh_token"] as? String else { throw APIError.invalidResponse }
        try save(GoogleTokens(accessToken: access, refreshToken: refresh,
                              expiresAt: Date().addingTimeInterval(json["expires_in"] as? Double ?? 3600)))
    }

    func accessToken(clientID: String) async throws -> String {
        guard let raw = try SecretStore.get("google.tokens"), let data = raw.data(using: .utf8),
              var tokens = try? JSONDecoder().decode(GoogleTokens.self, from: data) else { throw APIError.missingCredentials }
        if tokens.expiresAt > Date().addingTimeInterval(60) { return tokens.accessToken }
        var fields = ["client_id": clientID, "refresh_token": tokens.refreshToken, "grant_type": "refresh_token"]
        if let secret = try SecretStore.get("google.clientSecret"), !secret.isEmpty { fields["client_secret"] = secret }
        let json = try await tokenRequest(fields)
        guard let access = json["access_token"] as? String else { throw APIError.invalidResponse }
        tokens.accessToken = access
        tokens.expiresAt = Date().addingTimeInterval(json["expires_in"] as? Double ?? 3600)
        try save(tokens); return access
    }

    func cancel() { finish(.failure(CancellationError())); stop() }
    private func tokenRequest(_ fields: [String: String]) async throws -> [String: Any] {
        var request = HTTP.request(URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"; request.httpBody = HTTP.form(fields)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return try await HTTP.json(request)
    }
    private func save(_ value: GoogleTokens) throws {
        try SecretStore.set(String(decoding: JSONEncoder().encode(value), as: UTF8.self), for: "google.tokens")
    }
    private func receive(data: Data?, connection: NWConnection) {
        guard let data, let text = String(data: data, encoding: .utf8),
              let first = text.components(separatedBy: "\r\n").first,
              first.hasPrefix("GET "), let target = first.split(separator: " ").dropFirst().first,
              let url = URLComponents(string: "http://127.0.0.1\(target)") else {
            connection.cancel(); return
        }
        let query = url.queryItems ?? []
        let valid = url.path == "/oauth/callback" && query.first(where: { $0.name == "state" })?.value == state
        let code = query.first(where: { $0.name == "code" })?.value
        let accepted = valid && !receivedCallback && code != nil
        let body = accepted ? "Holdlet sign-in received. You can close this tab." : "Invalid or declined sign-in. Return to Holdlet."
        let response = "HTTP/1.1 \(accepted ? "200 OK" : "400 Bad Request")\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
        guard valid, !receivedCallback else { return }
        receivedCallback = true
        if let code { finish(.success(code)) } else { finish(.failure(APIError.provider("authorization_declined"))) }
    }
    private func finish(_ result: Result<String, Error>) {
        let pending = continuation; continuation = nil; pending?.resume(with: result)
    }
    private func stop() {
        timeout?.cancel(); timeout = nil; listener?.cancel(); listener = nil
        let pending = readyContinuation; readyContinuation = nil; pending?.resume(throwing: CancellationError())
    }
    private func randomURLSafe() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw APIError.provider("secure_random_failed") }
        return Data(bytes).base64URL
    }
}

private extension Data {
    var base64URL: String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
}
