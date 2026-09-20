import Foundation

public enum DetectedEncoding: String, Sendable, Equatable {
    case utf8
    case utf8BOM
    case windows1252
}

/// Sparkasse CSV exports show up as either UTF-8 or Windows-1252, with no
/// declared encoding in the file itself, so decoding has to be attempted
/// rather than assumed.
public enum EncodingDetector {
    public static func decode(_ data: Data) throws -> (text: String, encoding: DetectedEncoding) {
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        if data.count >= bom.count, Array(data.prefix(bom.count)) == bom {
            let stripped = data.suffix(from: data.startIndex + bom.count)
            guard let text = String(data: stripped, encoding: .utf8) else {
                throw ImportError.unreadableEncoding
            }
            return (text, .utf8BOM)
        }

        if let text = String(data: data, encoding: .utf8) {
            return (text, .utf8)
        }

        if let text = String(data: data, encoding: .windowsCP1252) {
            return (text, .windows1252)
        }

        throw ImportError.unreadableEncoding
    }
}
