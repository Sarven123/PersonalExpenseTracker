import Testing
@testable import PETCategorization

@Suite("MerchantNormalizer")
struct MerchantNormalizerTests {
    @Test("lowercases and strips a trailing GmbH suffix")
    func stripsGmbH() {
        #expect(MerchantNormalizer.normalize("REWE Markt GmbH") == "rewe markt")
    }

    @Test("strips the CAMT '//City/Country' purpose suffix")
    func stripsCityCountrySuffix() {
        #expect(MerchantNormalizer.normalize("REWE SAGT DANKE//München/DE") == "rewe sagt danke")
    }

    @Test("treats hyphens as word separators")
    func hyphensBecomeSpaces() {
        #expect(MerchantNormalizer.normalize("dm-drogerie markt GmbH") == "dm drogerie markt")
    }

    @Test("strips BV/SE/AG legal suffixes")
    func stripsOtherLegalSuffixes() {
        #expect(MerchantNormalizer.normalize("Netflix International BV") == "netflix international")
        #expect(MerchantNormalizer.normalize("Zalando SE") == "zalando")
    }

    @Test("collapses repeated whitespace")
    func collapsesWhitespace() {
        #expect(MerchantNormalizer.normalize("  Deutsche   Bahn  ") == "deutsche bahn")
    }

    @Test("normalizing an empty string yields an empty string")
    func emptyStaysEmpty() {
        #expect(MerchantNormalizer.normalize("") == "")
    }

    @Test("is idempotent")
    func idempotent() {
        let once = MerchantNormalizer.normalize("REWE Markt GmbH")
        #expect(MerchantNormalizer.normalize(once) == once)
    }
}
