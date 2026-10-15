import Foundation
import Testing
import HoldletCore
@testable import HoldletApp

private final class FixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let status: Int, body: String, headers: [String: String]
        switch url.path {
        case "/invalid-client":
            status = 401; body = #"{"error":"invalid_client","error_description":"never expose this synthetic credential"}"#; headers = [:]
        case "/disabled-api":
            status = 403; body = #"{"error":{"status":"PERMISSION_DENIED","details":[{"reason":"SERVICE_DISABLED"}]}}"#; headers = [:]
        case "/rate-limit": status = 429; body = "{}"; headers = ["Retry-After": "45"]
        case "/invalid-json": status = 200; body = "not-json"; headers = [:]
        default: status = 200; body = #"{"access_token":"synthetic-test-token","expires_in":3600}"#; headers = [:]
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

struct HTTPTests {
    func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureProtocol.self]
        return URLSession(configuration: configuration)
    }
    @Test func tokenResponseTravelsThroughActualHTTPClient() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        let result = try await HTTP.json(HTTP.request(URL(string: "https://fixture.invalid/token")!), session: session)
        #expect(result["expires_in"] as? Int == 3600)
    }
    @Test func oauthFailuresAreActionableAndDoNotExposeRemoteSecrets() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        do {
            _ = try await HTTP.json(HTTP.request(URL(string: "https://fixture.invalid/invalid-client")!), session: session)
            Issue.record("Expected invalid-client failure")
        } catch let error as ProviderFailure {
            #expect(error.code == "invalid_client")
            #expect(!error.localizedDescription.contains("synthetic credential"))
        }
    }
    @Test func disabledAPISurvivesHTTPErrorDecoding() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        do {
            _ = try await HTTP.json(HTTP.request(URL(string: "https://fixture.invalid/disabled-api")!), session: session)
            Issue.record("Expected disabled API failure")
        } catch let error as ProviderFailure { #expect(error.code == "SERVICE_DISABLED") }
    }
    @Test func retryAfterIsPreserved() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        do {
            _ = try await HTTP.json(HTTP.request(URL(string: "https://fixture.invalid/rate-limit")!), session: session)
            Issue.record("Expected rate limit")
        } catch APIError.rateLimited(let seconds) { #expect(seconds == 45) }
    }
    @Test func formEncodingPreservesPlusAndReservedCharacters() {
        let body = String(decoding: HTTP.form(["code": "a+b&c=d"]), as: UTF8.self)
        #expect(body == "code=a%2Bb%26c%3Dd")
    }
}
