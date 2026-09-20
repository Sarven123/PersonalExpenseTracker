import Foundation
import Testing
@testable import PETImport

@Suite("EncodingDetector")
struct EncodingDetectorTests {
    @Test("decodes plain UTF-8 data")
    func plainUTF8() throws {
        let data = Data("München".utf8)
        let (text, encoding) = try EncodingDetector.decode(data)
        #expect(text == "München")
        #expect(encoding == .utf8)
    }

    @Test("strips a UTF-8 byte-order mark")
    func utf8BOM() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("Köln".utf8))
        let (text, encoding) = try EncodingDetector.decode(data)
        #expect(text == "Köln")
        #expect(encoding == .utf8BOM)
    }

    @Test("falls back to Windows-1252 when bytes aren't valid UTF-8")
    func windows1252Fallback() throws {
        let data = "München".data(using: .windowsCP1252)!
        let (text, encoding) = try EncodingDetector.decode(data)
        #expect(text == "München")
        #expect(encoding == .windows1252)
    }

    @Test("throws on empty-but-unrepresentable byte sequences")
    func unrecognizable() {
        // 0x81 is undefined in Windows-1252 and invalid as a lone UTF-8 byte.
        let data = Data([0x81])
        #expect(throws: ImportError.self) {
            try EncodingDetector.decode(data)
        }
    }
}
