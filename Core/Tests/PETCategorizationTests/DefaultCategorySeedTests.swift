import Testing
@testable import PETCategorization

@Suite("DefaultCategorySeed")
struct DefaultCategorySeedTests {
    @Test("Contains exactly 14 unique categories with one transfer category")
    func hasFourteenUniqueEntries() {
        let all = DefaultCategorySeed.all
        #expect(all.count == 14)
        #expect(Set(all.map(\.name)).count == 14)
        #expect(all.filter(\.isTransferCategory).count == 1)
        #expect(all.first(where: { $0.isTransferCategory })?.name == "Transfers")
    }
}
