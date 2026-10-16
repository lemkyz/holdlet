import AppKit
import CryptoKit
import Foundation
import Network
import Security
import HoldletCore

struct GoogleTokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var clientID: String?
}

@MainActor
final class GoogleAuth {
    private var listener: NWListener?
    private var continuation: CheckedContinuation<String, Error>?
    private var readyContinuation: CheckedContinuation<UInt16, Error>?
    private var timeout: Task<Void, Never>?
    private var state = ""
    private var receivedCallback = false
    private var flowID = UUID()
    private var connections: [NWConnection] = []
    private(set) var busy = false
    private let openBrowser: (URL) -> Bool
    private let authorizationTimeout: Duration

    init(authorizationTimeout: Duration = .seconds(15 * 60),
         openBrowser: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }) {
        self.authorizationTimeout = authorizationTimeout
        self.openBrowser = openBrowser
    }

    func authorize(configuration: GoogleOAuthConfiguration) async throws {
        guard !busy else { throw APIError.provider("authorization_in_progress") }
        let clientID = configuration.clientID
        let attempt = UUID(); flowID = attempt
        busy = true; defer { busy = false; stop() }
        let deadline = authorizationTimeout
        timeout = Task { [weak self] in
            try? await Task.sleep(for: deadline)
            guard !Task.isCancelled, let self, self.flowID == attempt else { return }
            self.flowID = UUID()
            self.finish(.failure(APIError.provider("authorization_timed_out")))
            self.stop()
        }
        state = try randomURLSafe(); let verifier = try randomURLSafe()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let server = try NWListener(using: parameters)
        listener = server
        // NWListener fails with EINVAL if it starts without an accept handler.
        // Install this before waiting for .ready, rather than after readiness.
        server.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            Task { @MainActor [weak self] in
                self?.connections.append(connection)
                self?.receiveHeader(connection, buffered: Data())
            }
        }
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
            var parts = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
            let fields = ["client_id": clientID, "redirect_uri": redirect, "response_type": "code",
                "scope": "https://www.googleapis.com/auth/calendar.events.readonly https://www.googleapis.com/auth/gmail.readonly",
                "access_type": "offline", "prompt": "consent", "state": state,
                "code_challenge": challenge, "code_challenge_method": "S256"]
            parts.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let url = parts.url, openBrowser(url) else {
                finish(.failure(APIError.provider("browser_could_not_open"))); return
            }
        }
        guard flowID == attempt else { throw CancellationError() }
        var fields = ["client_id": clientID, "code": code, "code_verifier": verifier,
                      "redirect_uri": redirect, "grant_type": "authorization_code"]
        if !configuration.clientSecret.isEmpty { fields["client_secret"] = configuration.clientSecret }
        let json = try await tokenRequest(fields)
        guard flowID == attempt else { throw CancellationError() }
        guard let access = json["access_token"] as? String, let refresh = json["refresh_token"] as? String else { throw APIError.invalidResponse }
        if configuration.clientSecret.isEmpty { try await SecretStore.delete("google.clientSecret") }
        else { try await SecretStore.set(configuration.clientSecret, for: "google.clientSecret") }
        guard flowID == attempt else { throw CancellationError() }
        let tokens = GoogleTokens(accessToken: access, refreshToken: refresh,
                                  expiresAt: Date().addingTimeInterval(json["expires_in"] as? Double ?? 3600), clientID: clientID)
        let saved = String(decoding: try JSONEncoder().encode(tokens), as: UTF8.self)
        try await SecretStore.set(saved, for: "google.tokens")
        guard flowID == attempt else {
            try? await SecretStore.delete("google.tokens", matching: saved)
            throw CancellationError()
        }
    }

    func accessToken(clientID: String) async throws -> String {
        guard let raw = try await SecretStore.get("google.tokens"), let data = raw.data(using: .utf8),
              var tokens = try? JSONDecoder().decode(GoogleTokens.self, from: data) else { throw APIError.missingCredentials }
        guard tokens.clientID == nil || tokens.clientID == clientID else { throw APIError.provider("google_client_changed") }
        if tokens.expiresAt > Date().addingTimeInterval(60) { return tokens.accessToken }
        var fields = ["client_id": clientID, "refresh_token": tokens.refreshToken, "grant_type": "refresh_token"]
        if let secret = try await SecretStore.get("google.clientSecret"), !secret.isEmpty { fields["client_secret"] = secret }
        let json = try await tokenRequest(fields)
        guard let access = json["access_token"] as? String else { throw APIError.invalidResponse }
        tokens.accessToken = access
        tokens.expiresAt = Date().addingTimeInterval(json["expires_in"] as? Double ?? 3600)
        let updated = String(decoding: try JSONEncoder().encode(tokens), as: UTF8.self)
        try await SecretStore.replace(updated, for: "google.tokens", matching: raw)
        return access
    }

    func cancel() { flowID = UUID(); finish(.failure(CancellationError())); stop() }
    private func tokenRequest(_ fields: [String: String]) async throws -> [String: Any] {
        var request = HTTP.request(URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"; request.httpBody = HTTP.form(fields)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return try await HTTP.json(request)
    }
    private func receiveHeader(_ connection: NWConnection, buffered: Data) {
        guard buffered.count < 16384 else { connection.cancel(); return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384 - buffered.count) { [weak self] data, _, ended, error in
            Task { @MainActor [weak self] in
                guard let self else { connection.cancel(); return }
                var all = buffered
                if let data { all.append(data) }
                if all.range(of: Data("\r\n\r\n".utf8)) != nil { self.receive(data: all, connection: connection) }
                else if error != nil || ended { connection.cancel() }
                else { self.receiveHeader(connection, buffered: all) }
            }
        }
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
        let accepted = valid && !receivedCallback && code?.isEmpty == false
        let body = accepted ? "Authorization response received. Return to Holdlet to check the connection status." : "Invalid or declined sign-in. Return to Holdlet."
        let response = "HTTP/1.1 \(accepted ? "200 OK" : "400 Bad Request")\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
        guard valid, !receivedCallback else { return }
        receivedCallback = true
        if let code, !code.isEmpty { finish(.success(code)) }
        else { finish(.failure(ProviderFailure(status: 403, code: "access_denied"))) }
    }
    private func finish(_ result: Result<String, Error>) {
        let pending = continuation; continuation = nil; pending?.resume(with: result)
    }
    private func stop() {
        timeout?.cancel(); timeout = nil; listener?.cancel(); listener = nil
        connections.forEach { $0.cancel() }; connections.removeAll()
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
