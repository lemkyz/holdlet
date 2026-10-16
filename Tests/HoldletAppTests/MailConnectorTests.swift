import Foundation
import Testing
import HoldletCore
@testable import HoldletApp

private final class MailFixture: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "gmail.googleapis.com" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { query.first { $0.name == name }?.value }
        var status = 200
        let body: String
        if request.value(forHTTPHeaderField: "Authorization") != "Bearer synthetic" {
            status = 401; body = "{}"
        } else if url.path.hasSuffix("/profile") {
            body = #"{"historyId":"123456"}"#
        } else if url.path.hasSuffix("/threads") {
            if value("q") != "in:inbox" || value("maxResults") != "50" { status = 400; body = "{}" }
            else if value("pageToken") == "older-page" { body = #"{"threads":[{"id":"def"}]}"# }
            else { body = #"{"threads":[{"id":"abc"}],"nextPageToken":"older-page"}"# }
        } else if url.path.hasSuffix("/bad") {
            status = 404; body = "{}"
        } else if value("format") != "metadata" {
            status = 400; body = "{}"
        } else {
            let id = url.lastPathComponent
            body = "{\"id\":\"\(id)\",\"messages\":[{\"id\":\"\(id)1\",\"internalDate\":\"1792137600000\",\"labelIds\":[\"INBOX\"],\"payload\":{\"headers\":[{\"name\":\"Subject\",\"value\":\"Synthetic mail\"}]}}]}"
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: [:])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

struct MailConnectorTests {
    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MailFixture.self]
        return URLSession(configuration: configuration)
    }
    @Test func mailPaginationLoadsBothPagesInsteadOfRejectingLargeInbox() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        let first = try await GoogleConnector.mailPage(token: "synthetic", query: "in:inbox", session: session)
        #expect(first.items.map(\.id) == ["gmail.abc"])
        #expect(first.nextPageToken == "older-page")
        let second = try await GoogleConnector.mailPage(token: "synthetic", query: "in:inbox", pageToken: first.nextPageToken, session: session)
        #expect(second.items.map(\.id) == ["gmail.def"])
        #expect(second.nextPageToken == nil)
        #expect(first.items.first?.receivedAt != nil)
    }
    @Test func changeProbeReadsHistoryWithoutDownloadingMailbox() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        #expect(try await GoogleConnector.mailboxHistoryID(token: "synthetic", session: session) == "123456")
    }
    @Test func removedThreadDoesNotBreakRemainingMailAndDuplicateIDsAreMerged() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        let items = try await GoogleConnector.mailThreads(token: "synthetic", ids: ["abc", "abc", "bad"], session: session)
        #expect(items.map(\.id) == ["gmail.abc"])
    }
    @Test func unsafeThreadIDsCannotBecomeEndpointPaths() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        do {
            _ = try await GoogleConnector.mailThreads(token: "synthetic", ids: ["../profile"], session: session)
            Issue.record("Expected invalid thread ID rejection")
        } catch APIError.invalidResponse { }
    }
}
