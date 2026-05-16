import Foundation
import UIKit

private struct BramClientDiagnostics: Encodable {
    let appVersion: String
    let buildNumber: String
    let osVersion: String
    let deviceModel: String
    let locale: String
    let timezone: String
    let screen: String?
    let recentLogs: [DiagnosticLogEntry]

    @MainActor
    static func current(screen: String? = nil) -> BramClientDiagnostics {
        let bundle = Bundle.main
        return BramClientDiagnostics(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            osVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            deviceModel: UIDevice.current.model,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            screen: screen,
            recentLogs: AppDiagnosticsRecorder.shared.recentLogs()
        )
    }
}

struct BramSupportClient: SupportRequestSubmitting {
    enum ClientError: LocalizedError {
        case invalidResponse
        case requestFailed(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Support returned an invalid response."
            case .requestFailed(let status): "Support request failed with status \(status)."
            }
        }
    }

    private struct RequestBody: Encodable {
        let category: String
        let message: String
        let contactEmail: String?
        let diagnostics: BramClientDiagnostics?
        let source: String?
    }

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func configuredFromBundle(_ bundle: Bundle = .main) -> BramSupportClient? {
        guard let urlString = bundle.object(forInfoDictionaryKey: "BramAPIBaseURL") as? String,
              let url = URL(string: urlString)
        else { return nil }

        return BramSupportClient(baseURL: url)
    }

    func submit(_ draft: SupportRequestDraft, accessToken: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/api/support/request"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                category: draft.category.rawValue,
                message: draft.message,
                contactEmail: draft.contactEmail,
                diagnostics: draft.includeDiagnostics ? await .current(screen: draft.source ?? "settings_support") : nil,
                source: draft.source
            )
        )

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ClientError.requestFailed(httpResponse.statusCode)
        }
    }
}

struct BramErrorReportClient: AppErrorReporting {
    enum ClientError: LocalizedError {
        case invalidResponse
        case requestFailed(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Error reporting returned an invalid response."
            case .requestFailed(let status): "Error reporting failed with status \(status)."
            }
        }
    }

    private struct RequestBody: Encodable {
        let severity: String
        let source: String
        let eventName: String
        let message: String?
        let errorCode: String?
        let diagnostics: BramClientDiagnostics
        let metadata: [String: String]
    }

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func configuredFromBundle(_ bundle: Bundle = .main) -> BramErrorReportClient? {
        guard let urlString = bundle.object(forInfoDictionaryKey: "BramAPIBaseURL") as? String,
              let url = URL(string: urlString)
        else { return nil }

        return BramErrorReportClient(baseURL: url)
    }

    func report(_ report: AppErrorReport, accessToken: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/api/telemetry/error"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                severity: report.severity.rawValue,
                source: report.source,
                eventName: report.eventName,
                message: report.message,
                errorCode: report.errorCode,
                diagnostics: await .current(screen: report.source),
                metadata: report.metadata
            )
        )

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ClientError.requestFailed(httpResponse.statusCode)
        }
    }
}
