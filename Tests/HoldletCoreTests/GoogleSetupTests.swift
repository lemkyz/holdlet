import Foundation
import Testing
@testable import HoldletCore

struct GoogleSetupTests {
    @Test func importsDesktopClientAndSecretTogether() throws {
        let data = Data(#"{"installed":{"client_id":"123-test.apps.googleusercontent.com","client_secret":"synthetic-secret"}}"#.utf8)
        let configuration = try GoogleOAuthConfiguration(desktopJSON: data)
        #expect(configuration.clientID == "123-test.apps.googleusercontent.com")
        #expect(configuration.clientSecret == "synthetic-secret")
    }
    @Test func rejectsWebClientAndMalformedFiles() {
        #expect(throws: GoogleOAuthConfiguration.SetupError.self) {
            try GoogleOAuthConfiguration(desktopJSON: Data(#"{"web":{"client_id":"123-test.apps.googleusercontent.com"}}"#.utf8))
        }
        #expect(throws: GoogleOAuthConfiguration.SetupError.self) {
            try GoogleOAuthConfiguration(desktopJSON: Data("not-json".utf8))
        }
        #expect(throws: GoogleOAuthConfiguration.SetupError.self) {
            try GoogleOAuthConfiguration(desktopJSON: Data(repeating: 65, count: 65_537))
        }
    }
    @Test func invalidClientIDsCannotBecomeAuthorizationParameters() {
        for id in ["", "some-app", "client.apps.googleusercontent.com&scope=anything", "client\n.apps.googleusercontent.com"] {
            #expect(throws: GoogleOAuthConfiguration.SetupError.self) { try GoogleOAuthConfiguration(clientID: id) }
        }
    }
    @Test func failuresKeepUsefulReasonsWithoutLeakingRemoteDescriptions() {
        let payload = Data(#"{"error":"invalid_client","error_description":"synthetic-secret private@example.invalid"}"#.utf8)
        let error = ProviderFailure.decode(status: 401, data: payload)
        #expect(error.code == "invalid_client")
        #expect(!error.message(language: "tr").contains("synthetic-secret"))
        #expect(!error.message(language: "en").contains("private@"))
    }
    @Test func disabledGoogleAPIMatchesSpecificReason() {
        let data = Data(#"{"error":{"status":"PERMISSION_DENIED","details":[{"reason":"SERVICE_DISABLED"}]}}"#.utf8)
        let error = ProviderFailure.decode(status: 403, data: data)
        #expect(error.code == "SERVICE_DISABLED")
        #expect(error.message(language: "tr").contains("etkin"))
    }
    @Test func existingPreferencesCanDecodeWithoutNewOptionalCalendarFlag() throws {
        let preferences = Preferences()
        let data = try JSONEncoder().encode(preferences)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "googleCalendarEnabled")
        let oldData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Preferences.self, from: oldData)
        #expect(decoded.googleCalendarEnabled == nil)
    }
    @Test func macCalendarDoesNotDisableGmail() {
        var preferences = Preferences()
        preferences.connectGoogle(clientID: "123-test.apps.googleusercontent.com")
        preferences.selectMacCalendar()
        #expect(preferences.googleEnabled)
        #expect(!preferences.usesGoogleCalendar)
        preferences.selectGoogleCalendar(true)
        #expect(preferences.usesGoogleCalendar)
        #expect(!preferences.calendarEnabled)
        #expect(preferences.googleEnabled)
    }
    @Test func googleSignInKeepsExistingMacCalendar() {
        var preferences = Preferences()
        preferences.selectMacCalendar()
        preferences.connectGoogle(clientID: "123-test.apps.googleusercontent.com")
        #expect(preferences.calendarEnabled)
        #expect(preferences.googleEnabled)
        #expect(!preferences.usesGoogleCalendar)
    }
}
