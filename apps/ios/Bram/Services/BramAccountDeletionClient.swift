import Foundation

struct BramAccountDeletionClient: BramAccountDeleting {
    enum ClientError: LocalizedError {
        case notConfigured
        case invalidResponse
        case requestFailed(Int)

        var errorDescription: String? {
            switch self {
            case .notConfigured: "Account deletion is not configured."
            case .invalidResponse: "Account deletion returned an invalid response."
            case .requestFailed(let status): "Account deletion failed with status \(status)."
            }
        }
    }

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func configuredFromBundle(_ bundle: Bundle = .main) -> BramAccountDeletionClient? {
        guard let urlString = bundle.object(forInfoDictionaryKey: "BramAPIBaseURL") as? String,
              let url = URL(string: urlString)
        else { return nil }

        return BramAccountDeletionClient(baseURL: url)
    }

    func deleteAccount(accessToken: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/api/account/delete"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ClientError.requestFailed(httpResponse.statusCode)
        }
    }
}
