import Foundation

public enum ImportError: Error, LocalizedError, Equatable, Sendable {
    case emptyFile
    case unreadableEncoding
    case noHeaderRow
    case unsupportedLayout
    case malformedRow(line: Int, reason: String)
    case invalidDate(line: Int, rawValue: String)
    case invalidAmount(line: Int, rawValue: String)

    public var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The selected file is empty."
        case .unreadableEncoding:
            return "The file's text encoding could not be recognized (tried UTF-8 and Windows-1252)."
        case .noHeaderRow:
            return "The file has no header row to read column names from."
        case .unsupportedLayout:
            return "The column layout doesn't match a known Sparkasse CSV export format (CAMT or MT940)."
        case let .malformedRow(line, reason):
            return "Row \(line) is malformed: \(reason)."
        case let .invalidDate(line, rawValue):
            return "Row \(line) has an unreadable date: \"\(rawValue)\"."
        case let .invalidAmount(line, rawValue):
            return "Row \(line) has an unreadable amount: \"\(rawValue)\"."
        }
    }
}
