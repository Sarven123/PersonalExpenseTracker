import Foundation
import SwiftData

/// A place holdings live (e.g. "Midas"). Deliberately carries no credential or
/// provider-link field — this model can only ever be a manually-tracked label,
/// never an automation target.
@Model
public final class InvestmentAccount {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var notes: String?
    public var isArchived: Bool
    public var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Holding.account)
    public var holdings: [Holding]? = []

    public init(
        id: UUID = UUID(),
        name: String,
        notes: String? = nil,
        isArchived: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}
