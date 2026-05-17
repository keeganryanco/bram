import Foundation

struct BramPromoRedemptionClient: BramPromoRedeeming {
    enum ClientError: LocalizedError {
        case invalidResponse
        case requestFailed(Int, String?)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "Promo redemption returned an invalid response."
            case .requestFailed(_, let message):
                message ?? "Could not redeem that promo code."
            }
        }
    }

    private struct RequestBody: Encodable {
        let code: String
    }

    private struct ErrorBody: Decodable {
        let message: String?
    }

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func configuredFromBundle(_ bundle: Bundle = .main) -> BramPromoRedemptionClient? {
        guard let urlString = bundle.object(forInfoDictionaryKey: "BramAPIBaseURL") as? String,
              let url = URL(string: urlString)
        else { return nil }

        return BramPromoRedemptionClient(baseURL: url)
    }

    func redeem(code: String, accessToken: String) async throws -> AccountSnapshot {
        var request = URLRequest(url: baseURL.appending(path: "/api/account/redeem-promo"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(RequestBody(code: code))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorBody = try? JSONDecoder().decode(ErrorBody.self, from: data)
            throw ClientError.requestFailed(httpResponse.statusCode, errorBody?.message)
        }

        return try JSONDecoder().decode(AccountSnapshot.self, from: data)
    }
}
