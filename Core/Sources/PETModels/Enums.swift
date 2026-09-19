import Foundation

public enum TransactionType: String, Codable, CaseIterable, Sendable {
    case expense
    case income
    case transfer
}

public enum TransactionSource: String, Codable, CaseIterable, Sendable {
    case manual
    case imported
}

public enum RecurringFrequency: String, Codable, CaseIterable, Sendable {
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly
}

public enum RuleMatchType: String, Codable, CaseIterable, Sendable {
    case contains
    case exact
    case startsWith
    case regex
}

public enum RuleOrigin: String, Codable, CaseIterable, Sendable {
    case builtIn
    case userCorrection
}

public enum ImportSourceFormat: String, Codable, CaseIterable, Sendable {
    case camtCSV
    case mt940CSV
}
