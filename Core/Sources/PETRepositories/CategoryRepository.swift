import Foundation
import SwiftData
import PETModels
import PETCategorization

public enum CategoryRepositoryError: Error, LocalizedError, Equatable {
    case cannotDeleteSystemDefault
    case duplicateName(String)

    public var errorDescription: String? {
        switch self {
        case .cannotDeleteSystemDefault:
            "Built-in categories can’t be deleted, only renamed or recolored."
        case .duplicateName(let name):
            "A category named “\(name)” already exists."
        }
    }
}

@MainActor
public final class CategoryRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [ExpenseCategory] {
        var descriptor = FetchDescriptor<ExpenseCategory>()
        descriptor.sortBy = [SortDescriptor(\.sortOrder)]
        return try context.fetch(descriptor)
    }

    @discardableResult
    public func seedDefaultCategoriesIfNeeded() throws -> [ExpenseCategory] {
        let existing = try fetchAll()
        guard existing.isEmpty else { return existing }
        let created = DefaultCategorySeed.all.map { definition in
            ExpenseCategory(
                name: definition.name,
                colorHex: definition.colorHex,
                symbolName: definition.symbolName,
                sortOrder: definition.sortOrder,
                isTransferCategory: definition.isTransferCategory,
                isSystemDefault: true
            )
        }
        created.forEach { context.insert($0) }
        try context.save()
        return created
    }

    @discardableResult
    public func create(name: String, colorHex: String, symbolName: String) throws -> ExpenseCategory {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = try fetchAll()
        guard !all.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            throw CategoryRepositoryError.duplicateName(trimmed)
        }
        let nextSortOrder = (all.map(\.sortOrder).max() ?? -1) + 1
        let category = ExpenseCategory(
            name: trimmed,
            colorHex: colorHex,
            symbolName: symbolName,
            sortOrder: nextSortOrder
        )
        context.insert(category)
        try context.save()
        return category
    }

    public func rename(_ category: ExpenseCategory, to newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = try fetchAll()
        guard !all.contains(where: { $0.id != category.id && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            throw CategoryRepositoryError.duplicateName(trimmed)
        }
        category.name = trimmed
        try context.save()
    }

    public func recolor(_ category: ExpenseCategory, colorHex: String) throws {
        category.colorHex = colorHex
        try context.save()
    }

    public func setSymbol(_ category: ExpenseCategory, symbolName: String) throws {
        category.symbolName = symbolName
        try context.save()
    }

    public func delete(_ category: ExpenseCategory, reassigningTransactionsTo fallback: ExpenseCategory?) throws {
        guard !category.isSystemDefault else {
            throw CategoryRepositoryError.cannotDeleteSystemDefault
        }
        for transaction in category.transactions ?? [] {
            transaction.category = fallback
        }
        for rule in category.merchantRules ?? [] {
            rule.category = fallback
        }
        context.delete(category)
        try context.save()
    }
}
