import Foundation
import SwiftData
import Testing
import PETModels

@Suite("App-level SwiftData integration")
struct ModelContainerFactoryIntegrationTests {
    @Test("Live schema initializes an in-memory container without error")
    @MainActor
    func schemaInitializes() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Utilities", colorHex: "#95E1D3", symbolName: "bolt.fill")
        let transaction = Transaction(
            bookingDate: .now,
            amount: Decimal(-19.99),
            type: .expense,
            merchant: "Stadtwerke",
            rawDescription: "STADTWERKE SEPA-LASTSCHRIFT",
            source: .manual,
            category: category
        )
        context.insert(category)
        context.insert(transaction)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Transaction>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.category?.name == "Utilities")
    }
}
