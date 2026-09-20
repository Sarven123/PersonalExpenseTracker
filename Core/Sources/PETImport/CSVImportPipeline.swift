import Foundation
import PETModels

public struct ImportParseResult: Sendable {
    public let sourceFormat: ImportSourceFormat
    public let detectedEncoding: DetectedEncoding
    public let drafts: [DraftTransaction]
    public let warnings: [ImportError]
}

/// End-to-end parsing of a raw Sparkasse CSV export into draft transactions.
/// Malformed individual rows are collected as warnings rather than aborting
/// the whole import, so one bad row in a large export doesn't block the rest.
public enum CSVImportPipeline {
    public static func parse(fileData: Data) throws -> ImportParseResult {
        guard !fileData.isEmpty else {
            throw ImportError.emptyFile
        }

        let (text, encoding) = try EncodingDetector.decode(fileData)
        let rows = CSVParser.parse(text)

        guard let header = rows.first else {
            throw ImportError.noHeaderRow
        }

        let mapping = try ColumnMapping.detect(headerRow: header)

        var drafts: [DraftTransaction] = []
        var warnings: [ImportError] = []

        for (offset, row) in rows.dropFirst().enumerated() {
            let rowNumber = offset + 2 // 1-based; row 1 is the header
            do {
                let draft = try ImportRowMapper.map(row: row, mapping: mapping, rowNumber: rowNumber)
                drafts.append(draft)
            } catch let error as ImportError {
                warnings.append(error)
            } catch {
                warnings.append(.malformedRow(line: rowNumber, reason: "\(error)"))
            }
        }

        return ImportParseResult(
            sourceFormat: mapping.sourceFormat,
            detectedEncoding: encoding,
            drafts: drafts,
            warnings: warnings
        )
    }
}
