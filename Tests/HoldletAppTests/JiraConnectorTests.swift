import Foundation
import Testing
import HoldletCore
@testable import HoldletApp

private final class JiraFixture: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { ["example.atlassian.net", "api.atlassian.com"].contains(request.url?.host ?? "") }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if request.url!.path == "/_edge/tenant_info" {
            let status = request.value(forHTTPHeaderField: "Authorization") == nil ? 200 : 400
            respond(status: status, body: #"{"cloudId":"01234567-1234-1234-1234-123456789abc"}"#)
            return
        }
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let cursor = query.first { $0.name == "nextPageToken" }?.value
        let loopAuth = "Basic " + Data("loop@example.invalid:synthetic".utf8).base64EncodedString()
        let looping = request.value(forHTTPHeaderField: "Authorization") == loopAuth
        let first = "{\"issues\":[{\"key\":\"TEST-1\",\"fields\":{\"summary\":\"Synthetic\"}}],\"isLast\":false,\"nextPageToken\":\"next\"}"
        let second = "{\"issues\":[{\"key\":\"TEST-1\",\"fields\":{}},{\"key\":\"TEST-2\",\"fields\":{\"summary\":\"Second\"}}],\"isLast\":true}"
        let body = cursor == nil || looping ? first : second
        let jql = query.first { $0.name == "jql" }?.value ?? ""
        let status = jql.contains("reporter = currentUser()") && jql.contains("watcher = currentUser()") ? 200 : 400
        respond(status: status, body: body)
    }
    private func respond(status: Int, body: String) {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: [:])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

struct JiraConnectorTests {
    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [JiraFixture.self]
        return URLSession(configuration: configuration)
    }
    @Test func involvedIssuesAreReadAcrossPagesAndDeduplicated() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        let items = try await JiraConnector.fetch(site: "https://example.atlassian.net", email: "test@example.invalid", token: "synthetic", session: session)
        #expect(items.map(\.title) == ["TEST-1 · Synthetic", "TEST-2 · Second"])
    }
    @Test func repeatedCursorFailsInsteadOfLoopingOrSilentlyTruncating() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        do {
            _ = try await JiraConnector.fetch(site: "https://example.atlassian.net", email: "loop@example.invalid", token: "synthetic", session: session)
            Issue.record("Expected repeated cursor rejection")
        } catch APIError.invalidResponse { }
    }
    @Test func scopedTokenUsesGatewayAndPreservesHumanIssueLinks() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        let items = try await JiraConnector.fetch(site: "https://example.atlassian.net", email: "test@example.invalid", token: "synthetic", scopedToken: true, session: session)
        #expect(items.count == 2)
        #expect(items.first?.url?.host == "example.atlassian.net")
        #expect(items.first?.url?.path == "/browse/TEST-1")
    }
}
