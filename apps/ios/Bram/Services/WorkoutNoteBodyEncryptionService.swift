import CryptoKit
import Foundation
import Security

struct EncryptedWorkoutNoteBody: Equatable, Sendable {
    var ciphertext: String
    var nonce: String
    var keyVersion: Int
    var algorithm: String
}

protocol WorkoutNoteBodyEncrypting: Sendable {
    func encrypt(_ body: String, userId: UUID) throws -> EncryptedWorkoutNoteBody?
}

struct WorkoutNoteBodyEncryptionService: WorkoutNoteBodyEncrypting {
    enum EncryptionError: LocalizedError {
        case unableToCreateKey
        case unableToStoreKey(OSStatus)
        case unableToReadKey(OSStatus)
        case invalidKey
        case invalidNonce

        var errorDescription: String? {
            switch self {
            case .unableToCreateKey: "Could not create a local encryption key."
            case .unableToStoreKey(let status): "Could not store the local encryption key (\(status))."
            case .unableToReadKey(let status): "Could not read the local encryption key (\(status))."
            case .invalidKey: "The local encryption key is invalid."
            case .invalidNonce: "Could not create a note encryption nonce."
            }
        }
    }

    private let keyStore: WorkoutNoteBodyKeyStoring

    init(keyStore: WorkoutNoteBodyKeyStoring = KeychainWorkoutNoteBodyKeyStore()) {
        self.keyStore = keyStore
    }

    func encrypt(_ body: String, userId: UUID) throws -> EncryptedWorkoutNoteBody? {
        guard !body.isEmpty else { return nil }

        let key = SymmetricKey(data: try keyStore.keyData(userId: userId))
        let nonceData = try randomNonceData()
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealed = try AES.GCM.seal(Data(body.utf8), using: key, nonce: nonce)
        guard let combined = sealed.combined else { throw EncryptionError.invalidNonce }

        return EncryptedWorkoutNoteBody(
            ciphertext: combined.base64EncodedString(),
            nonce: nonceData.base64EncodedString(),
            keyVersion: 1,
            algorithm: "AES-256-GCM"
        )
    }

    private func randomNonceData() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 12)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw EncryptionError.invalidNonce }
        return Data(bytes)
    }
}

protocol WorkoutNoteBodyKeyStoring: Sendable {
    func keyData(userId: UUID) throws -> Data
}

struct KeychainWorkoutNoteBodyKeyStore: WorkoutNoteBodyKeyStoring {
    private let service = "app.trybram.Bram.workout-note-body"

    func keyData(userId: UUID) throws -> Data {
        let account = userId.uuidString.lowercased()
        if let existing = try readKey(account: account) {
            guard existing.count == 32 else { throw WorkoutNoteBodyEncryptionService.EncryptionError.invalidKey }
            return existing
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard randomStatus == errSecSuccess else {
            throw WorkoutNoteBodyEncryptionService.EncryptionError.unableToCreateKey
        }
        let key = Data(bytes)
        try storeKey(key, account: account)
        return key
    }

    func deleteKey(userId: UUID) throws {
        let status = SecItemDelete(baseQuery(account: userId.uuidString.lowercased()) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WorkoutNoteBodyEncryptionService.EncryptionError.unableToReadKey(status)
        }
    }

    private func readKey(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw WorkoutNoteBodyEncryptionService.EncryptionError.unableToReadKey(status)
        }
        return item as? Data
    }

    private func storeKey(_ key: Data, account: String) throws {
        var query = baseQuery(account: account)
        query[kSecValueData as String] = key
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw WorkoutNoteBodyEncryptionService.EncryptionError.unableToStoreKey(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
