# PersonalExpenseTracker

## Project Overview
A private, local-only personal expense tracker for macOS, written in Swift 6 / SwiftUI / SwiftData / Swift Charts. Single-user, single-Mac, no accounts, no cloud sync, no analytics, no network calls. Primary bank source is Sparkasse (Germany); currency is EUR with German date/number conventions. UI language is English. Deployment target is macOS 14+. The codebase is deliberately split into a platform-agnostic Swift package (`Core/`, product `PETCore`) and a thin macOS app shell (`App/macOS/`) so an iOS target can be added later with minimal rework.

Being built in 8 phases, one phase per work session (the original phase plan is kept outside this repo, in the local Claude Code plans directory, since it is session/tooling metadata rather than project source). This file is the persistent handoff record between sessions — read it before doing any work, update it before ending any session.

## Product Requirements
- Native macOS SwiftUI expense tracker, opened/run through Xcode.
- English UI; EUR currency; German date (DD.MM.YYYY) and decimal-comma number conventions by default.
- macOS 14+ deployment target; Swift 6; no third-party dependencies unless unavoidable.
- SwiftData for all local persistence; Swift Charts for interactive visualizations (hover tooltips).
- Sparkasse (Germany) CSV import: CSV-CAMT and CSV-MT940-style exports. No PDF import in v1. Resilient to semicolon delimiters, German decimal commas/thousands separators, UTF-8 and Windows-1252 encoding. Column-mapping + preview UI (layouts vary by region). Duplicate detection with a review step before commit. Never request bank credentials.
- Transactions: default categories (Food, Transport, Entertainment, Subscriptions, Housing, Utilities, Health, Shopping, Travel, Education, Fees, Income, Transfers, Other) plus user-created/custom categories (rename, recolor, manage). Transparent local rule-based category auto-suggestion. Recurring/subscription detection. Every field editable. Category corrections become local merchant rules. "Uncategorized" review filter. Transfers can be excluded from analytics.
- Manual entries: prominent "Add Expense" action, manual income too, appears identically to imported data everywhere.
- Dashboard: current-period total vs. prior period, interactive category donut/bar chart with hover tooltips, interactive time-series chart with hover, weekly summary (total/day-by-day/leading categories), recent transactions, top merchants, recurring/subscription summary, thoughtful empty state with opt-in (never automatic) demo data.
- Navigation: sidebar with Dashboard, Transactions, Insights, Settings. Filters (date range, month, week, category, merchant, type, source, transfers include/exclude) consistently affect every metric/chart/table. Searchable/sortable transaction table. CSV export of filtered transactions. Insights by category/merchant/month + subscriptions.
- Privacy: all data local via SwiftData, no network calls, no unnecessary logging of sensitive content. Settings: backup export, "Delete All Local Data" behind a confirmation dialog.
- Engineering quality: feature-based folders, README, unit tests for German parsing/CSV parsing/categorization/duplicate detection/summary calculations, must build and test clean via `xcodebuild`.
- Future iPhone/iOS extensibility: shared logic and views isolated from macOS-specific chrome.

## Architecture
```
PersonalExpenseTracker/
├── App/macOS/                    macOS-only: app entry point, window/menu chrome, sidebar shell, Resources
│   ├── PersonalExpenseTrackerApp.swift   @main, injects ModelContainer, attaches AppCommands
│   ├── ContentView.swift                 NavigationSplitView root (Dashboard/Transactions/Insights/Settings)
│   ├── Sidebar/SidebarView.swift
│   ├── Commands/AppCommands.swift        Cmd+N placeholder; more shortcuts added later
│   └── Resources/ (Assets.xcassets, Info.plist, PersonalExpenseTracker.entitlements)
├── PersonalExpenseTrackerTests/  Thin XCTest/Swift-Testing bundle for app-level/SwiftData integration checks
├── Fixtures/                     Fictional Sparkasse CSV samples (UTF-8 CAMT, Windows-1252 CAMT, MT940-style)
├── Core/                         Local SwiftPM package "PETCore" — all platform-agnostic logic lives here
│   ├── Package.swift              swift-tools-version 6.0; platforms .macOS(.v14) + .iOS(.v17) declared now
│   ├── Sources/PETModels/         SwiftData models + ModelContainerFactory (only target implemented so far)
│   └── Tests/PETModelsTests/      Swift Testing tests for the models
└── PersonalExpenseTracker.xcodeproj/   Hand-authored project.pbxproj + shared scheme + workspace data
```

**Planned future package targets** (not yet created — add to `Core/Package.swift` when their phase starts): `PETImport` (CSV/encoding/date/number parsing), `PETCategorization` (rule engine, merchant normalization, recurring detection), `PETRepositories` (CRUD + analytics aggregation), `PETExport` (CSV/backup export), `PETSharedUI` (all SwiftUI feature views, platform-agnostic).

**SwiftData schema (implemented in `Core/Sources/PETModels`):**
- `ExpenseCategory` — id, name, colorHex, symbolName, sortOrder, isTransferCategory, isSystemDefault, createdAt; relationships to `transactions` and `merchantRules`. **Named `ExpenseCategory`, not `Category`** — see Important Decisions.
- `Transaction` — id, bookingDate, valueDate?, amount (Decimal, signed), currencyCode, type (.expense/.income/.transfer), merchant, rawDescription (original bank text preserved), purpose?, bookingText?, iban?, counterpartyIBAN?, notes?, isRecurring, source (.manual/.imported), isExcludedFromAnalytics, dedupeHash, categorySuggestionSource?, createdAt, modifiedAt; relationships to `category`, `importBatch`, `recurringSchedule`.
- `RecurringSchedule` — id, frequency, interval, startDate, endDate?, dayOfMonth?, nextExpectedDate?, isActive; relationship to `transaction`.
- `MerchantRule` — id, matchType, pattern, priority, origin (.builtIn/.userCorrection), isRecurringHint, matchCount, createdAt; relationship to `category`.
- `ImportBatch` — id, importedAt, sourceFileName, sourceFormat, detectedEncoding, columnMapping (Data/JSON), rowCount, importedCount, skippedDuplicateCount, notes?; relationship to `transactions`.
- Delete rules: Category→Transaction `.nullify`, ImportBatch→Transaction `.nullify`, MerchantRule→Category `.nullify` (never cascade-delete spending data).
- `ModelContainerFactory` provides `makeLiveContainer()`, `makeInMemoryContainer()`, `previewContainer`.

**Import pipeline / categorization logic / reusable components:** not yet implemented (Phases 3–5).

**Xcode project mechanics:** `project.pbxproj` was hand-authored (no Xcode GUI, no xcodegen) using deterministic sha1-derived object IDs (see generator script used during Phase 1, not checked into the repo — recreate similarly if the pbxproj ever needs regenerating by script rather than by Edit). The app target links the local package product `PETModels` via `XCLocalSwiftPackageReference`/`XCSwiftPackageProductDependency`. A shared scheme (`xcshareddata/xcschemes/PersonalExpenseTracker.xcscheme`) was added manually so `xcodebuild -scheme PersonalExpenseTracker` works without ever opening Xcode's GUI. Code signing uses `CODE_SIGN_IDENTITY = "-"` (ad hoc / "Sign to Run Locally") — no Apple Developer team required for local builds.

## Completed
- [x] Directory scaffold created at `./PersonalExpenseTracker` (App/macOS, Core, Fixtures, Tests, .xcodeproj).
- [x] Local SwiftPM package `Core/` with product `PETModels`; builds standalone via `swift build`.
- [x] Full SwiftData schema (ExpenseCategory, Transaction, MerchantRule, ImportBatch, RecurringSchedule) + `ModelContainerFactory`.
- [x] Hand-authored `.xcodeproj` (project.pbxproj, shared scheme, workspace data) with app target + test target, both wired to the local package.
- [x] SwiftUI navigation shell: `NavigationSplitView` sidebar with Dashboard/Transactions/Insights/Settings placeholders.
- [x] App Sandbox entitlements (no network entitlement; read-only user-selected-file access) wired into the app target.
- [x] Asset catalog (AppIcon slots unpopulated, AccentColor set), Info.plist, entitlements file.
- [x] Three fictional Sparkasse CSV fixtures (UTF-8 CAMT, Windows-1252 CAMT, MT940-style) with umlauts and an embedded-semicolon quoted field.
- [x] `.gitignore` for Xcode/SwiftPM/macOS artifacts.
- [x] Verified: `swift build` and `swift test` pass inside `Core/` (2 tests).
- [x] Verified: `xcodebuild build` and `xcodebuild test` succeed for the app scheme (1 integration test).
- [x] Verified: built `.app` launches and stays running without crashing (manually opened and quit during Phase 1).

## In Progress
Nothing is currently mid-implementation. Phase 1 (scaffold) is closed out. Phase 2 (categories + manual transaction CRUD) has not been started yet.

## Remaining Work
Prioritized by the 8-phase roadmap (see plan file referenced above):
1. **Phase 2 — Categories + manual transaction CRUD:** `DefaultCategorySeed` (14 categories), `CategoryRepository`, `TransactionRepository`, Add/Edit Transaction sheet, basic transaction list, Category Manager (create/rename/recolor/delete-with-reassignment).
2. **Phase 3 — CSV import parsing engine (no UI):** encoding detector, German number/date parsers, quote-aware semicolon CSV parser, CAMT/MT940 header-alias layouts, `ColumnMapping`, row mapper, duplicate detector, actionable `ImportError`; tests against the Phase 1 fixtures.
3. **Phase 4 — Import UI:** file picker, column-mapping step, preview + parse warnings, duplicate-review step, commit → `ImportBatch` + `Transaction`s.
4. **Phase 5 — Categorization engine:** `CategoryRuleEngine`, `MerchantNormalizer`, builtin rules, manual-correction-creates-rule, `RecurringDetector`, MerchantRule manager UI, Uncategorized filter.
5. **Phase 6 — Dashboard + Swift Charts:** `AnalyticsRepository` aggregations, donut/bar + time-series charts with hover, weekly summary, recent transactions, top merchants, recurring summary, empty state with opt-in demo data.
6. **Phase 7 — Filters, insights, search/sort/export, Settings:** shared `FilterCriteria`, searchable/sortable table, CSV export, Insights view, backup export, Delete All Local Data with confirmation.
7. **Phase 8 — Polish, README, final verification:** keyboard shortcuts, accessibility, light/dark QA, full README, clean `xcodebuild build`/`test` + `swift test` pass with all warnings fixed.

## Known Issues
- App icon (`AppIcon.appiconset`) has size slots declared but no actual images assigned — cosmetic only, does not block builds; expected to be addressed in Phase 8 polish.
- `Core/Package.swift` currently declares only the `PETModels` target/product. Adding `PETImport`, `PETCategorization`, `PETRepositories`, `PETExport`, `PETSharedUI` targets requires manually editing `Package.swift` at the start of their respective phases (SwiftPM auto-discovers new files within an *existing* target's `Sources/` folder, but a brand-new target must be declared manually).
- No known compile errors, test failures, or crashes as of the last verification below.

## Build and Test Status
- Last build command: `xcodebuild build -project PersonalExpenseTracker.xcodeproj -scheme PersonalExpenseTracker -destination 'platform=macOS'`
- Last build result: **BUILD SUCCEEDED**
- Last test command: `xcodebuild test -project PersonalExpenseTracker.xcodeproj -scheme PersonalExpenseTracker -destination 'platform=macOS'`
- Last test result: **TEST SUCCEEDED** (1 test in PersonalExpenseTrackerTests)
- Also verified independently: `swift build` and `swift test` inside `Core/` — both succeeded (2 tests in PETModelsTests).
- Date/time of last verification: 2026-09-20 (Phase 1 session).
- Warnings that still matter: none observed in the build logs at time of verification. Re-check after each phase since new source files may introduce new warnings.

## Version Control & Backup
- **Remote:** GitHub repository `PersonalExpenseTracker`, owned by the authenticated `gh` account. **Visibility: PRIVATE.** It must stay private through normal development; see `SECURITY.md` for the exact policy on when/how it may ever become public (requires a documented review **and** explicit written owner confirmation — never automatic).
- **Primary branch:** `main`.
- **Current branch:** `main`.
- **Latest commit:** see the bottom of this section / Session Handoff for the most recent hash — always update this after every push.
- **Last backup status:** see Session Handoff below for the latest push result.
- **Security findings from the pre-push review:** No secrets, tokens, private keys, `.env` files, certificates, real CSV exports, PDFs, SQLite databases, or real transaction data were found in any tracked file. One local absolute path (containing the local machine username) was found in an earlier draft of this file and was removed before the first commit. `Fixtures/*.csv` contain IBAN-*formatted* strings — these are fictional/placeholder values (e.g. the standard textbook example IBAN used throughout banking documentation, and merchant names using Germany's "Muster" = "sample" placeholder convention), not real accounts; documented in detail in `SECURITY.md`. No other findings.
- **Ongoing workflow:** after every meaningful milestone — update `CLAUDE.md` (+ `SECURITY.md` if the security posture changed) → run relevant build/tests → inspect `git diff`/`git status` for anything on the "never commit" list in `SECURITY.md` → commit with a descriptive message → push `main` → record the new commit hash and next step here.
- **Restore-from-backup note:** since the remote is authoritative and private, a full project restore is `git clone <repo-url>` followed by opening `PersonalExpenseTracker.xcodeproj` in Xcode (SwiftPM will resolve the local `Core` package automatically) — no other setup is required because there are no external credentials or cloud state to restore.

## Important Decisions
- **Renamed `Category` → `ExpenseCategory`.** Reason: `Category` collides with the Objective-C runtime's own `Category` typedef (`objc/runtime.h`), causing a real "ambiguous for type lookup" compile error once both Foundation/ObjC interop and the model module are visible together (hit this in the Phase 1 test target). Renaming once, early, avoids qualifying every reference throughout the whole app forever.
- **Core logic lives in a local Swift Package (`Core/`, product `PETCore`), not directly in the `.xcodeproj`.** Reason: SwiftPM auto-discovers new `.swift` files added to an existing target's `Sources/` folder, so most future phases won't require hand-editing `project.pbxproj` at all — only the thin `App/macOS` shell and `PersonalExpenseTrackerTests` need pbxproj entries when new files are added there. This was an explicit user-approved tradeoff over using `xcodegen` or a from-scratch GUI-created project.
- **`.xcodeproj` was hand-authored via a one-off generator script (not committed) using deterministic sha1-derived object IDs**, then validated with `plutil -lint` and `xcodebuild -list` before any build was attempted. If the pbxproj needs regenerating wholesale in a future session, prefer targeted `Edit` calls to add new file/build-file entries rather than regenerating the whole file, to avoid clobbering settings added in later phases.
- **Code signing set to ad hoc (`CODE_SIGN_IDENTITY = "-"`, `CODE_SIGN_STYLE = Automatic`, no team).** Reason: this is a personal, non-distributed app; matches Xcode's own "Sign to Run Locally" default and lets `xcodebuild` build/test/run without an Apple Developer account.
- **App Sandbox is on with only `com.apple.security.files.user-selected.read-only`; no network entitlement is present at all.** Reason: architecturally enforces the "no network calls" requirement rather than relying on code discipline alone.
- **Swift Testing framework (`import Testing`, `@Suite`/`@Test`) used instead of XCTest** for both the package tests and the app-level test target. Reason: it's the modern, Xcode-16+-native testing framework and works identically in `swift test` and `xcodebuild test`; XCTest remains available if a future phase needs UI-hosted tests that specifically require it.
- **Fixture CSVs use entirely fictional data** (no real bank accounts, IBANs, or transactions) per the privacy/safety requirement, and were generated by hand plus `iconv` for the Windows-1252 variant.

## Session Handoff
**What was done in this session:** Completed Phase 1 in full — created the project scaffold, the `PETCore` Swift package with the complete SwiftData schema, a hand-authored `.xcodeproj` with app + test targets wired to the local package, the SwiftUI navigation shell, App Sandbox entitlements, asset catalog, three fictional Sparkasse CSV fixtures, and `.gitignore`. Verified everything builds and tests pass via both `xcodebuild` and `swift build`/`swift test`, and confirmed the built app launches and runs without crashing. Also created this `CLAUDE.md` handoff file per user request.

**What remains:** Phases 2–8 of the roadmap (see Remaining Work above), starting with Phase 2.

**Exact next step:** Start Phase 2 — implement `DefaultCategorySeed` (14 default categories) and `CategoryRepository`/`TransactionRepository` in `Core/Sources/PETRepositories` (new package target — remember to add it to `Core/Package.swift`), then build the Add/Edit Transaction sheet, a basic transaction list, and a Category Manager view in the app/UI layer. Verify with `swift test` (repository CRUD) and a manual add/edit/delete smoke test, then `xcodebuild build`/`test` for the full app target.

**Command needed to continue:** From `PersonalExpenseTracker/`: `xcodebuild build -project PersonalExpenseTracker.xcodeproj -scheme PersonalExpenseTracker -destination 'platform=macOS'` (build) and `xcodebuild test -project PersonalExpenseTracker.xcodeproj -scheme PersonalExpenseTracker -destination 'platform=macOS'` (test); `cd Core && swift build && swift test` for package-only iteration.

**Any user decision still required:** None at this time — proceed with Phase 2 as planned unless redirected.
