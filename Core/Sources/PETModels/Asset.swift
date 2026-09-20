import Foundation
import SwiftData

/// A plain inventory record — what you own and where, not a valuation. Deliberately has no
/// price, currency, cost-basis, or history fields: editing `quantity` is a plain field edit,
/// not an accounting operation, since there is no invariant (like average cost) to protect.
@Model
public final class Asset {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var ticker: String?
    public var assetType: AssetType
    public var accountOrLocation: String?
    public var quantity: Decimal
    public var unit: String
    /// Purity in per-mille (995 for the tracked physical gold instance). Nil for every other type.
    public var purityPerMille: Int?
    public var acquisitionDate: Date?
    public var notes: String?
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        ticker: String? = nil,
        assetType: AssetType,
        accountOrLocation: String? = nil,
        quantity: Decimal,
        unit: String,
        purityPerMille: Int? = nil,
        acquisitionDate: Date? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.ticker = ticker
        self.assetType = assetType
        self.accountOrLocation = accountOrLocation
        self.quantity = quantity
        self.unit = unit
        self.purityPerMille = purityPerMille
        self.acquisitionDate = acquisitionDate
        self.notes = notes
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
