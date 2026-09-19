import Foundation
import SwiftData

@Model
public final class ImportBatch {
    @Attribute(.unique) public var id: UUID
    public var importedAt: Date
    public var sourceFileName: String
    public var sourceFormat: ImportSourceFormat
    public var detectedEncoding: String
    public var columnMapping: Data
    public var rowCount: Int
    public var importedCount: Int
    public var skippedDuplicateCount: Int
    public var notes: String?

    @Relationship(deleteRule: .nullify, inverse: \ExpenseTransaction.importBatch)
    public var transactions: [ExpenseTransaction]? = []

    public init(
        id: UUID = UUID(),
        importedAt: Date = .now,
        sourceFileName: String,
        sourceFormat: ImportSourceFormat,
        detectedEncoding: String,
        columnMapping: Data = Data(),
        rowCount: Int = 0,
        importedCount: Int = 0,
        skippedDuplicateCount: Int = 0,
        notes: String? = nil
    ) {
        self.id = id
        self.importedAt = importedAt
        self.sourceFileName = sourceFileName
        self.sourceFormat = sourceFormat
        self.detectedEncoding = detectedEncoding
        self.columnMapping = columnMapping
        self.rowCount = rowCount
        self.importedCount = importedCount
        self.skippedDuplicateCount = skippedDuplicateCount
        self.notes = notes
    }
}
