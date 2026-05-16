import Foundation

struct BramPasswordResetClient: BramPasswordResetting {
    enum ClientError: LocalizedError {
        case invalidResponse
        case requestFailed(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Password reset returned an invalid response."
            case .requestFailed(let status): "Password reset failed with status \(status)."
            }
        }
    }

    private struct RequestBody: Encodable {
        let email: String
    }

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func configuredFromBundle(_ bundle: Bundle = .main) -> BramPasswordResetClient? {
        guard let urlString = bundle.object(forInfoDictionaryKey: "BramAPIBaseURL") as? String,
              let url = URL(string: urlString)
        else { return nil }

        return BramPasswordResetClient(baseURL: url)
    }

    func sendResetEmail(email: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/api/auth/password-reset/request"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(email: email))

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ClientError.requestFailed(httpResponse.statusCode)
        }
    }
}
