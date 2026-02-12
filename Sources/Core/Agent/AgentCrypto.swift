import Foundation
import CryptoKit

/// Provides AES-256-GCM encryption compatible with the Go agent's `security/crypto.go`.
///
/// Both sides derive the same 32-byte key from `AGENT_SECRET` using HKDF-SHA256
/// with identical salt and info parameters.
enum AgentCrypto {
    
    /// Derives a 256-bit symmetric key from the agent secret using HKDF.
    /// Must match the Go implementation exactly (same salt, info, hash function).
    static func deriveKey(from agentSecret: String) -> SymmetricKey {
        let inputKey = SymmetricKey(data: Data(agentSecret.utf8))
        let salt = Data("xyidactyl-salt".utf8)
        let info = Data("xyidactyl-api-key-encryption".utf8)
        
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: salt,
            info: info,
            outputByteCount: 32
        )
        return derivedKey
    }
    
    /// Encrypts plaintext API key to base64 string.
    /// Output format: base64(nonce || ciphertext || tag) — matches Go's `aesGCM.Seal(nonce, ...)`.
    static func encrypt(_ plaintext: String, secret: String) throws -> String {
        let key = deriveKey(from: secret)
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(Data(plaintext.utf8), using: key, nonce: nonce)
        
        // Go's Seal prepends nonce to (ciphertext + tag), which is sealedBox.combined
        guard let combined = sealedBox.combined else {
            throw AgentCryptoError.encryptionFailed
        }
        return combined.base64EncodedString()
    }
    
    /// Decrypts base64-encoded ciphertext back to plaintext.
    static func decrypt(_ encoded: String, secret: String) throws -> String {
        guard let data = Data(base64Encoded: encoded) else {
            throw AgentCryptoError.invalidBase64
        }
        
        let key = deriveKey(from: secret)
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decrypted = try AES.GCM.open(sealedBox, using: key)
        
        guard let plaintext = String(data: decrypted, encoding: .utf8) else {
            throw AgentCryptoError.invalidUTF8
        }
        return plaintext
    }
}

enum AgentCryptoError: LocalizedError {
    case encryptionFailed
    case invalidBase64
    case invalidUTF8
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed: return "Failed to encrypt data"
        case .invalidBase64: return "Invalid base64 encoded data"
        case .invalidUTF8: return "Decrypted data is not valid UTF-8"
        }
    }
}
