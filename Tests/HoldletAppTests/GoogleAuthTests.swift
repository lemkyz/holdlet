import Foundation
import Testing
import HoldletCore
@testable import HoldletApp

@MainActor
struct GoogleAuthTests {
    private func configuration() throws -> GoogleOAuthConfiguration {
        try GoogleOAuthConfiguration(clientID: "123-synthetic.apps.googleusercontent.com")
    }
    private func cancelAfterFiveSeconds(_ auth: GoogleAuth) -> Task<Void, Never> {
        Task {
            do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return }
            auth.cancel()
        }
    }

    @Test func actualLoopbackListenerBecomesReadyBeforeOpeningBrowserAndCanRetry() async throws {
        var opened: [URL] = []
        // No browser opens, no token exchange occurs and no Keychain value is written.
        let auth = GoogleAuth(openBrowser: { url in opened.append(url); return false })
        let safetyTimeout = cancelAfterFiveSeconds(auth)
        defer { safetyTimeout.cancel(); auth.cancel() }
        for _ in 0..<2 {
            do {
                try await auth.authorize(configuration: configuration())
                Issue.record("Expected the injected browser-open failure")
            } catch APIError.provider(let code) {
                #expect(code == "browser_could_not_open")
            }
            #expect(!auth.busy)
        }
        #expect(opened.count == 2)
        for url in opened {
            let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            func value(_ name: String) -> String? { query.first { $0.name == name }?.value }
            let redirect = try #require(value("redirect_uri").flatMap(URL.init(string:)))
            #expect(redirect.host == "127.0.0.1")
            #expect(redirect.path == "/oauth/callback")
            #expect((redirect.port ?? 0) > 0)
            #expect(value("code_challenge_method") == "S256")
            #expect(value("code_challenge")?.count == 43)
            #expect(!(value("state") ?? "").isEmpty)
        }
    }

    @Test func cancelAfterListenerReadinessCompletesAuthorizationWithoutSavingCredentials() async throws {
        var auth: GoogleAuth!
        var opened = false
        auth = GoogleAuth(openBrowser: { _ in
            opened = true
            Task { @MainActor in auth.cancel() }
            return true
        })
        let safetyTimeout = cancelAfterFiveSeconds(auth)
        defer { safetyTimeout.cancel(); auth.cancel() }
        do {
            try await auth.authorize(configuration: configuration())
            Issue.record("Expected cancellation")
        } catch is CancellationError { }
        #expect(opened)
        #expect(!auth.busy)
    }
}
