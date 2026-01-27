import Foundation

struct PterodactylFile: Codable, Identifiable {
    let object: String
    let attributes: FileAttributes
    
    var id: String { attributes.name }
}

struct FileAttributes: Codable {
    let name: String
    let mode: String
    let modeBits: String
    let size: Int
    let isFile: Bool
    let isSymlink: Bool
    let mimetype: String
    let createdAt: String
    let modifiedAt: String

    enum CodingKeys: String, CodingKey {
        case name, mode
        case modeBits = "mode_bits"
        case size
        case isFile = "is_file"
        case isSymlink = "is_symlink"
        case mimetype
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
    }
}
