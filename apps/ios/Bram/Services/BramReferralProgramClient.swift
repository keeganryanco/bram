import Foundation

struct BramReferralProgramClient: BramReferralProgramProviding {
    enum ClientError: LocalizedError {
        case invalidResponse
        case requestFailed(Int, String?)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "Referral program returned an invalid response."
            case .requestFailed(_, let message):
                message ?? "Could not load your referral code."
            }
        }
    }

    private struct ErrorBody: Decodable {
        let message: String?
    }

    private struct ClaimRequestBody: Encodable {
        let code: String
    }

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func configuredFromBundle(_ bundle: Bundle = .main) -> BramReferralProgramClient? {
        guard let urlString = bundle.object(forInfoDictionaryKey: "BramAPIBaseURL") as? String,
              let url = URL(string: urlString)
        else { return nil }

        return BramReferralProgramClient(baseURL: url)
    }

    func referralProgram(accessToken: String) async throws -> ReferralProgramStatus {
        var request = URLRequest(url: baseURL.appending(path: "/api/account/referral-code"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorBody = try? JSONDecoder().decode(ErrorBody.self, from: data)
            throw ClientError.requestFailed(httpResponse.statusCode, errorBody?.message)
        }

        return try JSONDecoder().decode(ReferralProgramStatus.self, from: data)
    }

    func claimReferral(code: String, accessToken: String) async throws -> AccountSnapshot {
        var request = URLRequest(url: baseURL.appending(path: "/api/account/claim-referral"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(ClaimRequestBody(code: code))

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
