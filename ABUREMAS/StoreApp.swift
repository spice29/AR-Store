
import Foundation

struct StoreApp: Identifiable, Decodable {
    let id: UUID
    let name: String
    let bundleID: String
    let version: String
    let description: String?
    let iconPath: String?
    let ipaPath: String?
    let sizeBytes: Int64?
    let published: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case bundleID = "bundle_id"
        case version
        case description
        case iconPath = "icon_path"
        case ipaPath = "ipa_path"
        case sizeBytes = "size_bytes"
        case published
    }
}
