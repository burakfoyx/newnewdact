import Foundation

struct FileListResponse: Codable {
    let object: String // "list"
    let data: [PterodactylFile]
}
