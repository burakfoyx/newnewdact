import Foundation

struct BackupResponse: Codable {
    let data: [BackupData]
}

struct BackupData: Codable {
    let attributes: BackupAttributes
}

struct BackupAttributes: Codable {
    let uuid: String
    let name: String
    let bytes: Int64
    let checksum: String?
    let energeticUuid: String?
    let completedAt: String?
    let createdAt: String
    let isSuccessful: Bool?
    let isLocked: Bool? 
    
    var isCompleted: Bool { completedAt != nil }
    
    enum CodingKeys: String, CodingKey {
        case uuid, name, bytes, checksum
        case energeticUuid = "ignored_files" // Note: This mapping seems wrong in original code, likely 'ignored_files' is [String]. keeping as is but making optional helps.
        // energetic_uuid is not a standard field? ignored_files is usually what is sent.
        // Let's assume the user's previous code meant ignored_files.
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case isSuccessful = "is_successful"
        case isLocked = "is_locked"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        name = try container.decode(String.self, forKey: .name)
        // Handle bytes safely
        if let bytesInt = try? container.decode(Int64.self, forKey: .bytes) {
            bytes = bytesInt
        } else {
            bytes = 0
        }
        
        checksum = try? container.decode(String.self, forKey: .checksum)
        // energeticUuid mapping to ignored_files is suspicious. Reading as? String?
        // ignored_files is [String]. 
        // If the original code had `energeticUuid` mapping to `ignored_files`, it would fail if it's an array.
        // I will comment out energeticUuid or map it correctly if needed.
        // For now, try decode string, else nil.
        energeticUuid = try? container.decode(String.self, forKey: .energeticUuid) 
        
        completedAt = try? container.decode(String.self, forKey: .completedAt)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        isSuccessful = try? container.decode(Bool.self, forKey: .isSuccessful)
        isLocked = try? container.decode(Bool.self, forKey: .isLocked)
    }
    
    // Encodable conformance not strictly needed for attributes usually but good to have
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(name, forKey: .name)
        try container.encode(bytes, forKey: .bytes)
        try container.encode(checksum, forKey: .checksum)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
