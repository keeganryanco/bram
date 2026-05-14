import Foundation
import Supabase

enum BramSupabaseConfigurationError: LocalizedError, Equatable {
    case missingValue(String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let key):
            "Missing \(key) in Bram Info.plist."
        case .invalidURL(let key):
            "Invalid \(key) in Bram Info.plist."
        }
    }
}

struct BramSupabaseConfiguration: Equatable {
    var supabaseURL: URL
    var publishableKey: String
    var redirectScheme: String

    var redirectURL: URL {
        URL(string: "\(redirectScheme)://auth-callback")!
    }

    static func fromBundle(_ bundle: Bundle = .main) throws -> BramSupabaseConfiguration {
        let urlString = try nonEmptyString("BramSupabaseURL", bundle: bundle)
        guard let url = URL(string: urlString) else {
            throw BramSupabaseConfigurationError.invalidURL("BramSupabaseURL")
        }

        return BramSupabaseConfiguration(
            supabaseURL: url,
            publishableKey: try nonEmptyString("BramSupabasePublishableKey", bundle: bundle),
            redirectScheme: try nonEmptyString("BramAuthRedirectScheme", bundle: bundle)
        )
    }

    private static func nonEmptyString(_ key: String, bundle: Bundle) throws -> String {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw BramSupabaseConfigurationError.missingValue(key)
        }
        return value
    }
}

enum BramSupabaseClientFactory {
    static func makeClient(configuration: BramSupabaseConfiguration) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: configuration.supabaseURL,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: configuration.redirectURL,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
