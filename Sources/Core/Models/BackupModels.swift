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
    let bytes: Int
    let checksum: String?
    let energeticUuid: String?
    let completedAt: String?
    let createdAt: String
    
    var isCompleted: Bool { completedAt != nil }
    
    enum CodingKeys: String, CodingKey {
        case uuid, name, bytes, checksum
        case energeticUuid = "ignored_files" // Mapping might vary, simplified
        case completedAt = "completed_at"
        case createdAt = "created_at"
    }
}
