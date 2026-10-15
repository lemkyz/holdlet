import Foundation

public struct GoogleOAuthConfiguration: Equatable, Sendable {
    public let clientID: String
    public let clientSecret: String

    public init(clientID: String, clientSecret: String = "") throws {
        let id = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard id.hasSuffix(".apps.googleusercontent.com"),
              id.count > ".apps.googleusercontent.com".count,
              id.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._").contains($0) }) else {
            throw SetupError.invalidClientID
        }
        self.clientID = id; self.clientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Accept Google's downloaded Desktop client file. A Web client has a different redirect policy.
    public init(desktopJSON data: Data) throws {
        guard data.count <= 65_536 else { throw SetupError.invalidFile }
        let root: [String: Any]
        do {
            guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw SetupError.invalidFile }
            root = value
        } catch { throw SetupError.invalidFile }
        if root["web"] != nil { throw SetupError.webClient }
        guard let installed = root["installed"] as? [String: Any], let id = installed["client_id"] as? String else { throw SetupError.invalidFile }
        try self.init(clientID: id, clientSecret: installed["client_secret"] as? String ?? "")
    }

    public enum SetupError: Error, LocalizedError {
        case invalidClientID, invalidFile, webClient
        public var errorDescription: String? {
            switch self {
            case .invalidClientID: "Enter a valid Google Desktop client ID or import its downloaded JSON file."
            case .invalidFile: "Select the Desktop OAuth client JSON downloaded from Google Cloud."
            case .webClient: "This is a Web application client. Create a Desktop app client in Google Cloud and import that file."
            }
        }
    }
}

public struct ProviderFailure: Error, LocalizedError, Equatable, Sendable {
    public let status: Int
    public let code: String
    public init(status: Int, code: String) { self.status = status; self.code = code }

    /// Keep only recognized error identifiers. Never echo remote descriptions containing user data.
    public static func decode(status: Int, data: Data) -> ProviderFailure {
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let nested = root["error"] as? [String: Any] ?? [:]
        let errors = nested["errors"] as? [[String: Any]] ?? []
        let details = nested["details"] as? [[String: Any]] ?? []
        let candidates = [root["error"] as? String, nested["status"] as? String]
            + errors.map { $0["reason"] as? String } + details.map { $0["reason"] as? String }
        let recognized: Set<String> = ["invalid_client", "invalid_grant", "access_denied", "invalid_scope", "redirect_uri_mismatch",
            "accessNotConfigured", "SERVICE_DISABLED", "insufficientPermissions", "ACCESS_TOKEN_SCOPE_INSUFFICIENT",
            "admin_policy_enforced", "org_internal", "invalid_token", "UNAUTHENTICATED", "PERMISSION_DENIED"]
        // Specific reasons override a generic PERMISSION_DENIED wrapper.
        let code = candidates.compactMap { $0 }.filter { recognized.contains($0) && $0 != "PERMISSION_DENIED" }.last
            ?? (status == 401 ? "UNAUTHENTICATED" : status == 403 ? "PERMISSION_DENIED" : "http_error")
        return ProviderFailure(status: status, code: code)
    }
    public var errorDescription: String? { message(language: "en") }
    public func message(language: String) -> String {
        let tr = language == "tr"
        switch code {
        case "invalid_client":
            return tr ? "Google istemci kimliği veya istemci sırrı geçersiz. Aynı Desktop app istemcisinin JSON dosyasını içe aktar." : "Google rejected the client ID or secret. Import the JSON for the same Desktop app client."
        case "invalid_grant", "invalid_token", "UNAUTHENTICATED":
            return tr ? "Oturumun süresi dolmuş veya erişim iptal edilmiş. Yeniden giriş yap." : "The session expired or access was revoked. Sign in again."
        case "accessNotConfigured", "SERVICE_DISABLED":
            return tr ? "İlgili Google API bu projede etkin değil. Gmail API veya Google Calendar API'yi etkinleştirip yeniden dene." : "The Google API is disabled for this project. Enable Gmail API or Google Calendar API and retry."
        case "insufficientPermissions", "ACCESS_TOKEN_SCOPE_INSUFFICIENT", "invalid_scope":
            return tr ? "Gerekli okuma izni verilmemiş. Yeniden giriş yapıp kullanacağın servis izinlerini gözden geçir." : "The required read permission is missing. Sign in again and review the service permissions."
        case "access_denied", "admin_policy_enforced", "org_internal", "PERMISSION_DENIED":
            return tr ? "Hesap veya kurum bu erişime izin vermiyor. Test kullanıcısını ve kurum uygulama izinlerini kontrol et." : "Your account or organization does not allow this access. Check the test user and organization app policy."
        case "redirect_uri_mismatch":
            return tr ? "Yönlendirme istemci türüyle eşleşmiyor. Web istemcisi yerine Desktop app istemcisini içe aktar." : "The redirect does not match the client type. Import a Desktop app client, not a Web client."
        default:
            return tr ? "Servis HTTP \(status) döndürdü. Bağlantı ayarlarını kontrol edip yeniden dene." : "The service returned HTTP \(status). Check the connection settings and retry."
        }
    }
}
