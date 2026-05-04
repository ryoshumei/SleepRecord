import XCTest
@testable import SleepRecord

/// Verifies that the en.lproj resources contain real (non-fallback) translations
/// for the validator message keys. If a key is missing, iOS's
/// localizedString(forKey:value:table:) returns the `value` parameter we pass in.
final class LocalizationCoverageTests: XCTestCase {

    /// Returns the en-localized bundle, or nil if the test target doesn't bundle it.
    func enBundle() -> Bundle? {
        guard let path = Bundle.main.path(forResource: "en", ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }

    func assertEnglish(_ key: String, file: StaticString = #file, line: UInt = #line) {
        guard let bundle = enBundle() else {
            XCTFail("en.lproj missing from bundle — Localizable.xcstrings may not be compiled with en", file: file, line: line)
            return
        }
        let sentinel = "<__missing__>"
        let translated = bundle.localizedString(forKey: key, value: sentinel, table: nil)
        XCTAssertNotEqual(translated, sentinel, "key '\(key)' has no en translation", file: file, line: line)
        XCTAssertFalse(translated.isEmpty, "key '\(key)' has empty en translation", file: file, line: line)
    }

    func testValidator_BedWindowInverted_HasEnglish() {
        assertEnglish("validator.bedWindowInverted")
    }

    func testValidator_AsleepBeforeBedIn_HasEnglish() {
        assertEnglish("validator.asleepBeforeBedIn")
    }

    func testValidator_AwakeAfterBedOut_HasEnglish() {
        assertEnglish("validator.awakeAfterBedOut")
    }

    func testValidator_AsleepAfterAwake_HasEnglish() {
        assertEnglish("validator.asleepAfterAwake")
    }
}
