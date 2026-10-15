import Foundation
import HoldletCore

enum APIError: LocalizedError {
    case invalidURL, rejected(Int), rateLimited(Int), invalidResponse, provider(String), missingCredentials
    var errorDescription: String? {
        switch self {
        case .invalidURL: "The service URL is invalid. Use an HTTPS address."
        case .rejected(let code): "Service returned HTTP \(code). Check permissions and credentials."
        case .rateLimited(let seconds): "Rate limit reached. Retry after \(seconds) seconds."
        case .invalidResponse: "The service returned an unexpected response."
        case .provider(let code): "Service error: \(code). Check the required access scopes."
        case .missingCredentials: "Connection credentials are missing. Open Connections to set them up."
        }
    }
}

enum HTTP {
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 45
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()

    static func request(_ url: URL, bearer: String? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        return request
    }
    static func json(_ request: URLRequest, session: URLSession = HTTP.session) async throws -> [String: Any] {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if response.statusCode == 429 {
            throw APIError.rateLimited(max(1, Int(response.value(forHTTPHeaderField: "Retry-After") ?? "120") ?? 120))
        }
        guard (200...299).contains(response.statusCode) else { throw ProviderFailure.decode(status: response.statusCode, data: data) }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw APIError.invalidResponse }
        return object
    }
    static func url(_ base: String, query: [String: String] = [:]) throws -> URL {
        guard var components = URLComponents(string: base), components.scheme == "https", components.host != nil else { throw APIError.invalidURL }
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw APIError.invalidURL }; return url
    }
    static func form(_ fields: [String: String]) -> Data {
        // Query encoding must escape literal '+' in form bodies.
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return Data(fields.sorted { $0.key < $1.key }.map {
            "\($0.key.addingPercentEncoding(withAllowedCharacters: safe)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: safe)!)"
        }.joined(separator: "&").utf8)
    }
}
