import SwiftUI
import UniformTypeIdentifiers

/// Minimal `FileDocument` wrapper so CSV export can use SwiftUI's
/// cross-platform `.fileExporter`, matching this package's no-AppKit rule.
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
