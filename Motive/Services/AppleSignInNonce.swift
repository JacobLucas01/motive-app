import CryptoKit
import Foundation

enum AppleSignInNonce {
    static func random(length: Int = 32) throws -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

        guard status == errSecSuccess else {
            throw AppleSignInNonceError.randomGenerationFailed(status)
        }

        let characters = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(characters)
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
}

enum AppleSignInNonceError: LocalizedError {
    case randomGenerationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .randomGenerationFailed(let status):
            return "Unable to prepare Apple sign-in nonce. OSStatus: \(status)."
        }
    }
}
