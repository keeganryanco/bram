import Foundation

struct BramAccountWelcomeEmailClient: BramWelcomeEmailSending {
    enum ClientError: LocalizedError {
        case invalidResponse
        case requestFailed(Int, String?)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "Welcome email returned an invalid response."
            case .requestFailed(_, let message):
                message ?? "Could not send the welcome email."
            }
        }
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

    static func configuredFromBundle(_ bundle: Bundle = .main) -> BramAccountWelcomeEmailClient? {
        guard let urlString = bundle.object(forInfoDictionaryKey: "BramAPIBaseURL") as? String,
              let url = URL(string: urlString)
        else { return nil }

        return BramAccountWelcomeEmailClient(baseURL: url)
    }

    func sendWelcomeEmail(accessToken: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/api/account/welcome-email"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorBody = try? JSONDecoder().decode(ErrorBody.self, from: data)
            throw ClientError.requestFailed(httpResponse.statusCode, errorBody?.message)
        }
    }
}

