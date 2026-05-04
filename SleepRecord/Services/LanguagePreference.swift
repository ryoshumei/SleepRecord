import Foundation
import SwiftUI

enum LanguageOption: String, CaseIterable, Identifiable, Hashable {
    case system = ""
    case japanese = "ja"
    case english = "en"
    var id: String { rawValue }
}

/// User's language preference. Backed by `UserDefaults.standard`.
/// `selected` is observable so SwiftUI Pickers bind to it directly.
@Observable
final class LanguagePreference {
    static let appleLanguagesKey = "AppleLanguages"
    static let userPrefKey = "appLanguage"

    static let shared = LanguagePreference()

    /// Test-only factory that bypasses the singleton so each test starts fresh.
    static func makeForTesting() -> LanguagePreference {
        LanguagePreference()
    }

    var selected: LanguageOption {
        didSet { apply() }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.userPrefKey) ?? ""
        self.selected = LanguageOption(rawValue: raw) ?? .system
    }

    private func apply() {
        let defaults = UserDefaults.standard
        defaults.set(selected.rawValue, forKey: Self.userPrefKey)
        switch selected {
        case .system:
            defaults.removeObject(forKey: Self.appleLanguagesKey)
        case .japanese, .english:
            defaults.set([selected.rawValue], forKey: Self.appleLanguagesKey)
        }
    }
}
