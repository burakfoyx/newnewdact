import Foundation

struct StartupResponse: Codable {
    let data: [StartupData]
}

struct StartupData: Codable {
    let attributes: StartupVariable
}

struct StartupVariable: Codable, Identifiable {
    let name: String
    let description: String
    let envVariable: String
    let defaultValue: String
    let serverValue: String
    let isEditable: Bool
    let rules: String
    
    var id: String { envVariable }
    
    enum CodingKeys: String, CodingKey {
        case name, description
        case envVariable = "env_variable"
        case defaultValue = "default_value"
        case serverValue = "server_value"
        case isEditable = "is_editable"
        case rules
    }
}
