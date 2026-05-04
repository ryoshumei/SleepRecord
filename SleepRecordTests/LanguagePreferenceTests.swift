import XCTest
@testable import SleepRecord

final class LanguagePreferenceTests: XCTestCase {
    let defaults = UserDefaults.standard

    override func tearDown() {
        defaults.removeObject(forKey: LanguagePreference.userPrefKey)
        defaults.removeObject(forKey: LanguagePreference.appleLanguagesKey)
        super.tearDown()
    }

    func testApplyEnglish_WritesAppleLanguages() {
        let pref = LanguagePreference.makeForTesting()
        pref.selected = .english
        XCTAssertEqual(defaults.array(forKey: LanguagePreference.appleLanguagesKey) as? [String], ["en"])
        XCTAssertEqual(defaults.string(forKey: LanguagePreference.userPrefKey), "en")
    }

    func testApplyJapanese_WritesAppleLanguages() {
        let pref = LanguagePreference.makeForTesting()
        pref.selected = .japanese
        XCTAssertEqual(defaults.array(forKey: LanguagePreference.appleLanguagesKey) as? [String], ["ja"])
        XCTAssertEqual(defaults.string(forKey: LanguagePreference.userPrefKey), "ja")
    }

    func testApplySystem_RemovesAppleLanguagesOverride() {
        // First set an override, then clear it.
        let pref = LanguagePreference.makeForTesting()
        pref.selected = .english
        XCTAssertEqual(defaults.array(forKey: LanguagePreference.appleLanguagesKey) as? [String], ["en"])

        pref.selected = .system
        // After clearing, AppleLanguages may fall through to the system domain
        // (NSGlobalDomain) — array(forKey:) is layered. We can't assert nil, but
        // the value must no longer equal our override, and the user pref must
        // have reset to empty.
        let after = defaults.array(forKey: LanguagePreference.appleLanguagesKey) as? [String]
        XCTAssertNotEqual(after, ["en"], "override should be cleared from standard domain")
        XCTAssertEqual(defaults.string(forKey: LanguagePreference.userPrefKey), "")
    }
}
