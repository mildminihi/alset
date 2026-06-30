import Foundation

/// Reads non-secret and secret values injected via Info.plist / xcconfig.
enum AppSecrets {
    static var supabaseAnonKey: String {
        bundleValue(for: "SUPABASE_ANON_KEY")
    }

    static var teslaClientSecret: String {
        bundleValue(for: "TESLA_CLIENT_SECRET")
    }

    private static func bundleValue(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.hasPrefix("your-") else {
            return ""
        }
        return value
    }
}
