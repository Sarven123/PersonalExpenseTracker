import Foundation

/// Loads the fictional Sparkasse CSV fixtures from the repo-level
/// `Fixtures/` directory (outside the `Core/` package boundary) using a
/// `#filePath`-derived path, so the same lookup works whether the tests
/// are run via `swift test` (cwd == `Core/`) or `xcodebuild test`
/// (cwd is a build-products directory).
enum FixtureLoader {
    static func url(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // FixtureLoader.swift -> PETImportTests/
            .deletingLastPathComponent() // PETImportTests/ -> Tests/
            .deletingLastPathComponent() // Tests/ -> Core/
            .deletingLastPathComponent() // Core/ -> repo root
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: url(name))
    }
}
