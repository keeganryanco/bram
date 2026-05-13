import Foundation

struct BramRevenueCatEntitlementRefreshClient: BramEntitlementRefreshing {
    enum ClientError: LocalizedError {
        case notConfigured
        case invalidResponse
        case requestFailed(Int)

        var errorDescription: String? {
            switch self {
            case .notConfigured: "Subscription refresh is not configured."
            case .invalidResponse: "Subscription refresh returned an invalid response."
            case .requestFailed(let status): "Subscription refresh failed with status \(status)."
            }
        }
    }

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func configuredFromBundle(_ bundle: Bundle = .main) -> BramRevenueCatEntitlementRefreshClient? {
        guard let urlString = bundle.object(forInfoDictionaryKey: "BramAPIBaseURL") as? String,
              let url = URL(string: urlString)
        else { return nil }

        return BramRevenueCatEntitlementRefreshClient(baseURL: url)
    }

    func refresh(accessToken: String) async throws -> AccountSnapshot {
        var request = URLRequest(url: baseURL.appending(path: "/api/revenuecat/refresh"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ClientError.requestFailed(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(AccountSnapshot.self, from: data)
    }
}
