import Foundation
import Testing
import PETModels
@testable import PETImport

@Suite("CSVImportPipeline against Sparkasse fixtures")
struct FixtureIntegrationTests {
    @Test("parses the UTF-8 CAMT fixture with no warnings")
    func utf8CAMTFixture() throws {
        let data = try FixtureLoader.data("sparkasse_camt_sample_utf8.csv")
        let result = try CSVImportPipeline.parse(fileData: data)

        #expect(result.sourceFormat == .camtCSV)
        #expect(result.detectedEncoding == .utf8)
        #expect(result.warnings.isEmpty)
        #expect(result.drafts.count == 8)

        let rewe = try #require(result.drafts.first)
        #expect(rewe.merchant == "REWE Markt GmbH")
        #expect(rewe.amount == Decimal(string: "-42.17"))
        #expect(rewe.type == .expense)
        #expect(rewe.purpose?.contains("München") == true)

        let salary = result.drafts[1]
        #expect(salary.amount == Decimal(string: "2450.00"))
        #expect(salary.type == .income)
    }

    @Test("parses the Windows-1252 CAMT fixture, decoding umlauts correctly")
    func windows1252CAMTFixture() throws {
        let data = try FixtureLoader.data("sparkasse_camt_sample_windows1252.csv")
        let result = try CSVImportPipeline.parse(fileData: data)

        #expect(result.sourceFormat == .camtCSV)
        #expect(result.detectedEncoding == .windows1252)
        #expect(result.warnings.isEmpty)
        #expect(result.drafts.count == 8)

        let rewe = try #require(result.drafts.first)
        #expect(rewe.purpose?.contains("München") == true)

        let refund = try #require(result.drafts.last)
        #expect(refund.purpose?.contains("Rückerstattung") == true)
        #expect(refund.amount == Decimal(string: "34.99"))
    }

    @Test("UTF-8 and Windows-1252 CAMT fixtures decode to identical content")
    func utf8AndWindows1252Match() throws {
        let utf8Result = try CSVImportPipeline.parse(
            fileData: try FixtureLoader.data("sparkasse_camt_sample_utf8.csv")
        )
        let cp1252Result = try CSVImportPipeline.parse(
            fileData: try FixtureLoader.data("sparkasse_camt_sample_windows1252.csv")
        )

        #expect(utf8Result.drafts.map(\.dedupeHash) == cp1252Result.drafts.map(\.dedupeHash))
    }

    @Test("parses the MT940-style fixture, including a purpose field with an embedded semicolon")
    func mt940Fixture() throws {
        let data = try FixtureLoader.data("sparkasse_mt940_sample.csv")
        let result = try CSVImportPipeline.parse(fileData: data)

        #expect(result.sourceFormat == .mt940CSV)
        #expect(result.warnings.isEmpty)
        #expect(result.drafts.count == 6)

        let gym = result.drafts[3]
        #expect(gym.merchant == "FitFirst Studios GmbH")
        #expect(gym.purpose == "Fitnessstudio Beitrag; Vertrag 445566")
        #expect(gym.amount == Decimal(string: "-29.90"))
        #expect(gym.ownIBAN == nil)
    }

    @Test("re-parsing the same fixture is fully flagged as duplicates against the first import")
    func reimportIsFlaggedAsDuplicate() throws {
        let data = try FixtureLoader.data("sparkasse_mt940_sample.csv")
        let first = try CSVImportPipeline.parse(fileData: data)
        let second = try CSVImportPipeline.parse(fileData: data)

        let existingHashes = Set(first.drafts.map(\.dedupeHash))
        let partitioned = DuplicateDetector.partition(drafts: second.drafts, existingHashes: existingHashes)

        #expect(partitioned.unique.isEmpty)
        #expect(partitioned.duplicates.count == first.drafts.count)
    }
}
