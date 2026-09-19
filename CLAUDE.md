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
│   ├── PersonalExpenseTrackerApp.swift   @main, injects ModelContainer, seeds default categories, forces de_DE locale
│   ├── ContentView.swift                 NavigationSplitView root (Dashboard/Transactions/Insights/Settings)
│   ├── Sidebar/SidebarView.swift
│   ├── Commands/AppCommands.swift        Cmd+N posts .petRequestAddExpense; more shortcuts added later
│   └── Resources/ (Assets.xcassets, Info.plist, PersonalExpenseTracker.entitlements)
├── PersonalExpenseTrackerTests/  Thin Swift-Testing bundle for app-level/SwiftData integration checks
├── Fixtures/                     Fictional Sparkasse CSV samples (UTF-8 CAMT, Windows-1252 CAMT, MT940-style)
├── Core/                         Local SwiftPM package "PETCore" — all platform-agnostic logic lives here
│   ├── Package.swift              swift-tools-version 6.0; platforms .macOS(.v14) + .iOS(.v17) declared now
│   ├── Sources/
│   │   ├── PETModels/             SwiftData models + ModelContainerFactory
│   │   ├── PETCategorization/     DefaultCategorySeed (14 categories); rule engine arrives Phase 5
│   │   ├── PETRepositories/       CategoryRepository, TransactionRepository (CRUD, all business rules)
│   │   └── PETSharedUI/           SwiftUI views: TransactionListView, TransactionEditView,
│   │                              CategoryManagerView, CategoryBadge, ColorHex, Notifications
│   └── Tests/
│       ├── PETModelsTests/, PETCategorizationTests/, PETRepositoriesTests/   Swift Testing
└── PersonalExpenseTracker.xcodeproj/   Hand-authored project.pbxproj + shared scheme + workspace data
```

**Planned future package targets** (not yet created — add to `Core/Package.swift` when their phase starts): `PETImport` (CSV/encoding/date/number parsing, Phase 3), `PETExport` (CSV/backup export, Phase 7). `PETCategorization` will gain `CategoryRuleEngine`/`MerchantNormalizer`/`RecurringDetector` in Phase 5.

**SwiftData schema (implemented in `Core/Sources/PETModels`):**
- `ExpenseCategory` — id, name, colorHex, symbolName, sortOrder, isTransferCategory, isSystemDefault, createdAt; relationships to `transactions` and `merchantRules`. **Named `ExpenseCategory`, not `Category`** — see Important Decisions.
- `ExpenseTransaction` — id, bookingDate, valueDate?, amount (Decimal, signed), currencyCode, type (.expense/.income/.transfer), merchant, rawDescription (original bank text preserved), purpose?, bookingText?, iban?, counterpartyIBAN?, notes?, isRecurring, source (.manual/.imported), isExcludedFromAnalytics, dedupeHash, categorySuggestionSource?, createdAt, modifiedAt; relationships to `category`, `importBatch`, `recurringSchedule`. **Named `ExpenseTransaction`, not `Transaction`** — see Important Decisions.
- `RecurringSchedule` — id, frequency, interval, startDate, endDate?, dayOfMonth?, nextExpectedDate?, isActive; relationship to `transaction`.
- `MerchantRule` — id, matchType, pattern, priority, origin (.builtIn/.userCorrection), isRecurringHint, matchCount, createdAt; relationship to `category`.
- `ImportBatch` — id, importedAt, sourceFileName, sourceFormat, detectedEncoding, columnMapping (Data/JSON), rowCount, importedCount, skippedDuplicateCount, notes?; relationship to `transactions`.
- Delete rules: Category→Transaction `.nullify`, ImportBatch→Transaction `.nullify`, MerchantRule→Category `.nullify` (never cascade-delete spending data).
- `ModelContainerFactory` provides `makeLiveContainer()`, `makeInMemoryContainer()` (each call gets a uniquely-named in-memory configuration — see Important Decisions), `previewContainer`.

**Categorization (Phase 2 slice, in `Core/Sources/PETCategorization`):** `DefaultCategorySeed.all` — the 14 default categories (Food, Transport, Entertainment, Subscriptions, Housing, Utilities, Health, Shopping, Travel, Education, Fees, Income, Transfers, Other) with color/symbol/sortOrder; `Transfers` is the one `isTransferCategory` entry. Seeded automatically on app launch via `CategoryRepository.seedDefaultCategoriesIfNeeded()` (idempotent — safe to call every launch). Rule-based auto-suggestion, merchant normalization, and recurring detection are **not yet implemented** (Phase 5).

**Repositories (`Core/Sources/PETRepositories`, both `@MainActor`):**
- `CategoryRepository` — `fetchAll()`, `seedDefaultCategoriesIfNeeded()`, `create/rename/recolor/setSymbol`, `delete(_:reassigningTransactionsTo:)` (rejects deleting a system-default category via `CategoryRepositoryError.cannotDeleteSystemDefault`; rejects duplicate names case-insensitively via `.duplicateName`).
- `TransactionRepository` — `fetchAll(sortedByDateDescending:)`, `createManualTransaction(...)`, `update(...)`, `delete(...)`. Callers pass a positive `magnitude`; the repository derives the signed `amount` from `TransactionType` (expense/transfer → negative, income → positive) — see Important Decisions.

**Shared UI (`Core/Sources/PETSharedUI`, pure SwiftUI, no AppKit):** `TransactionListView` (list + empty state + toolbar "Add Expense"/"Manage Categories"), `TransactionEditView` (Add/Edit sheet, `.create`/`.edit(ExpenseTransaction)` modes), `CategoryManagerView` (create/rename/recolor/delete-with-reassignment), `CategoryBadge`, `Color(hex:)`/`.toHex()` helpers, and `.petRequestAddExpense` notification (lets macOS menu commands trigger the Add Expense sheet from wherever `TransactionListView` is showing). These views are platform-agnostic by construction so an iOS target can reuse them.

**Import pipeline / recurring detection / analytics:** not yet implemented (Phases 3, 5, 6).

**Xcode project mechanics:** `project.pbxproj` was hand-authored (no Xcode GUI, no xcodegen) using deterministic sha1-derived object IDs (`gid(name) = sha1(name)[:24].uppercased()`, so the same logical name always yields the same ID — new entries are added by computing `gid()` for the new name and inserting via targeted `Edit` calls, not by regenerating the whole file). The app target links local package products (`PETModels`, `PETRepositories`, `PETSharedUI`) via `XCLocalSwiftPackageReference`/`XCSwiftPackageProductDependency`; the test target currently only links `PETModels`. A shared scheme (`xcshareddata/xcschemes/PersonalExpenseTracker.xcscheme`) was added manually so `xcodebuild -scheme PersonalExpenseTracker` works without ever opening Xcode's GUI. Code signing uses `CODE_SIGN_IDENTITY = "-"` (ad hoc / "Sign to Run Locally") — no Apple Developer team required for local builds.

## Completed
- [x] Directory scaffold created at `./PersonalExpenseTracker` (App/macOS, Core, Fixtures, Tests, .xcodeproj).
- [x] Local SwiftPM package `Core/` with products `PETModels`, `PETCategorization`, `PETRepositories`, `PETSharedUI`; builds standalone via `swift build`.
- [x] Full SwiftData schema (ExpenseCategory, ExpenseTransaction, MerchantRule, ImportBatch, RecurringSchedule) + `ModelContainerFactory`.
- [x] Hand-authored `.xcodeproj` (project.pbxproj, shared scheme, workspace data) with app target + test target, both wired to the local package.
- [x] SwiftUI navigation shell: `NavigationSplitView` sidebar with Dashboard/Transactions/Insights/Settings; Transactions is the default/live tab, the other three remain placeholders.
- [x] App Sandbox entitlements (no network entitlement; read-only user-selected-file access) wired into the app target.
- [x] Asset catalog (AppIcon slots unpopulated, AccentColor set), Info.plist, entitlements file.
- [x] Three fictional Sparkasse CSV fixtures (UTF-8 CAMT, Windows-1252 CAMT, MT940-style) with umlauts and an embedded-semicolon quoted field.
- [x] `.gitignore` for Xcode/SwiftPM/macOS artifacts; Git/GitHub backup workflow set up (see Version Control & Backup).
- [x] **Phase 2 — Categories + manual transaction CRUD:** `DefaultCategorySeed` (14 categories, auto-seeded on launch), `CategoryRepository` and `TransactionRepository` with full CRUD + validation, Add/Edit Transaction sheet (`TransactionEditView`), transaction list with empty state (`TransactionListView`), Category Manager (create/rename/recolor/delete-with-reassignment, system-default categories protected from deletion). German locale (`de_DE`) forced app-wide via `.environment(\.locale:)` so dates/amounts follow German conventions regardless of system locale.
- [x] Verified: `swift build` and `swift test` pass inside `Core/` (12 tests across PETModelsTests, PETCategorizationTests, PETRepositoriesTests).
- [x] Verified: `xcodebuild build` and `xcodebuild test` succeed for the app scheme (1 integration test).
- [x] Verified: built `.app` launches, stays running without crashing, and correctly seeds categories once (idempotent across relaunches) — checked by running the binary directly and inspecting stdout/stderr for errors.

## In Progress
Nothing is currently mid-implementation. Phase 2 is closed out. Phase 3 (CSV import parsing engine) has not been started yet.

## Remaining Work
Prioritized by the 8-phase roadmap:
1. **Phase 3 — CSV import parsing engine (no UI):** encoding detector, German number/date parsers, quote-aware semicolon CSV parser, CAMT/MT940 header-alias layouts, `ColumnMapping`, row mapper, duplicate detector, actionable `ImportError`; tests against the Phase 1 fixtures. New `PETImport` package target.
2. **Phase 4 — Import UI:** file picker, column-mapping step, preview + parse warnings, duplicate-review step, commit → `ImportBatch` + `ExpenseTransaction`s.
3. **Phase 5 — Categorization engine:** `CategoryRuleEngine`, `MerchantNormalizer`, builtin rules, manual-correction-creates-rule, `RecurringDetector`, MerchantRule manager UI, Uncategorized filter (expands the existing `PETCategorization` target).
4. **Phase 6 — Dashboard + Swift Charts:** `AnalyticsRepository` aggregations, donut/bar + time-series charts with hover, weekly summary, recent transactions, top merchants, recurring summary, empty state with opt-in demo data. Switch `ContentView`'s default tab back to Dashboard once it's real.
5. **Phase 7 — Filters, insights, search/sort/export, Settings:** shared `FilterCriteria`, searchable/sortable table (upgrade `TransactionListView`'s plain `List` to a `Table`), CSV export, Insights view, backup export, Delete All Local Data with confirmation. New `PETExport` package target.
6. **Phase 8 — Polish, README, final verification:** keyboard shortcuts, accessibility, light/dark QA, full README, clean `xcodebuild build`/`test` + `swift test` pass with all warnings fixed.

## Known Issues
- App icon (`AppIcon.appiconset`) has size slots declared but no actual images assigned — cosmetic only, does not block builds; expected to be addressed in Phase 8 polish.
- `Core/Package.swift` needs a manual edit each time a brand-new target is introduced (`PETImport` in Phase 3, `PETExport` in Phase 7) — SwiftPM only auto-discovers new files within an *already-declared* target's `Sources/` folder.
- `ContentView` defaults to the Transactions tab instead of Dashboard, since Dashboard is still a placeholder. Revert the default once Phase 6 ships.
- No known compile errors, test failures, or crashes as of the last verification below.

## Build and Test Status
- Last build command: `xcodebuild build -project PersonalExpenseTracker.xcodeproj -scheme PersonalExpenseTracker -destination 'platform=macOS'`
- Last build result: **BUILD SUCCEEDED**
- Last test command: `xcodebuild test -project PersonalExpenseTracker.xcodeproj -scheme PersonalExpenseTracker -destination 'platform=macOS'`
- Last test result: **TEST SUCCEEDED** (1 test in PersonalExpenseTrackerTests)
- Also verified independently: `swift build` and `swift test` inside `Core/` — both succeeded (12 tests: 2 PETModelsTests, 1 PETCategorizationTests, 9 PETRepositoriesTests).
- Date/time of last verification: 2026-09-20 (Phase 2 session).
- Warnings that still matter: none observed in the build logs at time of verification. Re-check after each phase since new source files may introduce new warnings.

## Version Control & Backup
- **Remote:** `https://github.com/Sarven123/PersonalExpenseTracker` (`origin`). **Visibility: PRIVATE** (verified via `gh repo view --json isPrivate` → `true`). It must stay private through normal development; see `SECURITY.md` for the exact policy on when/how it may ever become public (requires a documented review **and** explicit written owner confirmation — never automatic).
- **Primary branch:** `main`.
- **Current branch:** `main`.
- **Latest commit:** `b36aa0f` — "Phase 2: categories + manual transaction CRUD" (2026-09-20), on top of `f5edef2` and `5579c67` (Phase 1 scaffold + Git/GitHub setup commits).
- **Last backup status:** Pushed successfully — `main` is up to date with `origin/main`, working tree clean, as of 2026-09-20.
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
- **Renamed `Transaction` → `ExpenseTransaction`.** Reason: same class of bug as the `Category` rename — `Transaction` collides with `SwiftUI.Transaction` (the animation-transaction type) the moment a file imports both `SwiftUI` and the model module, producing an "ambiguous for type lookup" error. Hit this while building `PETSharedUI` in Phase 2. Given two collisions in two phases, treat any new model/type name as a candidate for an SDK collision before committing to it — grep Apple's frameworks mentally (or just pick a slightly more specific name up front) for common nouns like `Transaction`, `Category`, `Event`, `State`, `Task`, `Notification`.
- **`ModelContainerFactory.makeInMemoryContainer()` gives every call a uniquely-named `ModelConfiguration`** (`"in-memory-\(UUID().uuidString)"`) instead of the default unnamed configuration. Reason: defensive hardening against store-identity collisions across concurrently-created in-memory containers (relevant for parallel test execution); done while diagnosing the dangling-context test crash below, and kept even though it wasn't the actual root cause.
- **Test helpers must return the `ModelContainer`, never just `container.mainContext`.** Reason: a real bug was hit and fixed in Phase 2 — a `private func makeContext() -> ModelContext { ModelContainerFactory.makeInMemoryContainer().mainContext }` helper let the temporary `ModelContainer` get deallocated the instant the function returned (nothing retained it), leaving the returned `ModelContext` pointing at a torn-down in-memory store. This crashed with `SIGTRAP`/`EXC_BREAKPOINT` inside SwiftData on the *next* `insert`/`fetch`/`save`, non-deterministically depending on which test ran it — it was misdiagnosed at first as a Swift-Testing parallelism issue (which is why `.serialized` traits and unique container names were tried first) before the real cause was isolated by bisecting with scratch tests. Every test helper in this repo now returns `ModelContainer` and calls `.mainContext` at the point of use, keeping the container alive for the test's duration.
- **Manual transaction entry takes a positive `magnitude` and derives the signed `amount` from `TransactionType`** (expense/transfer → negative, income → positive) inside `TransactionRepository`, rather than asking the user to type a signed number. Reason: matches how people actually think about entering an expense ("I spent €40"), and keeps the sign convention centralized in one place instead of duplicated across every UI entry point.
- **German locale (`Locale(identifier: "de_DE")`) is forced app-wide via `.environment(\.locale:)`** on the root `ContentView`, rather than relying on `.locale()` modifiers on individual format styles. Reason: the product requirement is "German date/number conventions by default" regardless of the Mac's actual system locale; setting it once at the root is DRY and SwiftUI's format-style-based `Text`/`TextField` views pick up the environment locale automatically.
- **Default categories are seeded automatically on every app launch** (idempotent — `seedDefaultCategoriesIfNeeded()` no-ops if any category already exists), and this is treated as baseline setup, not as the "demo data" the product spec says must never be auto-inserted. Reason: the spec's demo-data restriction is about sample *transactions*, not the core category taxonomy the whole app depends on.
- **System-default categories (`isSystemDefault == true`) cannot be deleted**, only renamed/recolored; `CategoryRepository.delete` throws `.cannotDeleteSystemDefault` for them. Reason: protects the taxonomy that categorization rules (Phase 5) and analytics (Phase 6) will assume exists; custom categories can still be freely deleted with transaction reassignment.
- **`TransactionListView` uses a plain SwiftUI `List`, not `Table`, for now.** Reason: Phase 2 only needs a basic editable list; the spec's "searchable, sortable transaction table" requirement is explicitly a Phase 7 deliverable, so upgrading to `Table` now would be premature scope.

## Session Handoff

### Session 2 (Git/GitHub backup setup)
**What was done in this session:** Set up safe version control per the repository safety policy. Inspected the existing project (no prior git history) and confirmed `gh` was already authenticated with `repo` scope. Rewrote `.gitignore` to comprehensively cover Xcode/SwiftPM build products, all user-specific Xcode state (`xcuserdata/`, `*.xcuserstate`), SwiftData/Core Data local stores, local backups, real-bank-export filename patterns, and secrets/credentials/signing files — while explicitly re-including `/Fixtures/**` since those are required synthetic test data. Created `SECURITY.md` documenting the data-protection rules, the private-by-default publishing policy, and a security review record. Ran a full pre-commit security scan (secret patterns, local-path/username leakage) across every file staged for commit; found and removed one local absolute path (containing the machine username) from an earlier draft of this file, and confirmed the only IBAN-*shaped* strings anywhere in the repo are fictional fixture data (documented in `SECURITY.md`). Initialized git with `main` as the default branch, verified the exact staged file list matched intent (28 files — no build artifacts, no user state, no `.DS_Store`), re-ran `xcodebuild build` as a pre-commit sanity check, committed, created the GitHub repository as **private**, added it as `origin`, and pushed `main`.

**What remains:** Phases 2–8 of the product roadmap (see Remaining Work above) are all still outstanding — this session only addressed version control, not new app features.

**Exact next step:** Start Phase 2 — implement `DefaultCategorySeed` (14 default categories) and `CategoryRepository`/`TransactionRepository` in `Core/Sources/PETRepositories` (new package target — remember to add it to `Core/Package.swift`), then build the Add/Edit Transaction sheet, a basic transaction list, and a Category Manager view in the app/UI layer. Verify with `swift test` (repository CRUD) and a manual add/edit/delete smoke test, then `xcodebuild build`/`test` for the full app target. After that milestone, follow the Ongoing Backup Workflow above (update `CLAUDE.md`/`SECURITY.md`, run tests, review diff for sensitive data, commit, push).

**Command needed to continue:** From `PersonalExpenseTracker/`: `xcodebuild build -project PersonalExpenseTracker.xcodeproj -scheme PersonalExpenseTracker -destination 'platform=macOS'` (build) and `xcodebuild test -project PersonalExpenseTracker.xcodeproj -scheme PersonalExpenseTracker -destination 'platform=macOS'` (test); `cd Core && swift build && swift test` for package-only iteration. To sync with GitHub: `git status`, `git add -A`, `git commit -m "..."`, `git push`.

**Any user decision still required:** None for now. The repository will remain private through all remaining phases; a future request to publish it publicly requires a fresh security review plus your explicit written confirmation (see `SECURITY.md`) — do not ask for that confirmation prematurely, only when the app reaches a genuinely stable, reviewed milestone.

### Session 3 (Phase 2 — categories + manual transaction CRUD)
**What was done in this session:** Implemented Phase 2 in full. Added three new `Core` package targets (`PETCategorization` with `DefaultCategorySeed`; `PETRepositories` with `CategoryRepository`/`TransactionRepository`; `PETSharedUI` with `TransactionListView`/`TransactionEditView`/`CategoryManagerView`/`CategoryBadge`/`ColorHex`/`Notifications`), wired the app to seed default categories on launch and force the `de_DE` locale app-wide, wired `ContentView`'s Transactions tab and `AppCommands`'s Cmd+N to the new UI, and hand-edited `project.pbxproj` to add `PETRepositories`/`PETSharedUI` as app-target package product dependencies. Hit and fixed two real bugs along the way: (1) `Transaction` collided with `SwiftUI.Transaction`, requiring the same rename treatment as `Category` did in Phase 1 — renamed to `ExpenseTransaction` throughout; (2) a `SIGTRAP` crash in the new `PETRepositoriesTests` traced (via crash-report parsing and bisection with scratch tests) to a test helper returning `container.mainContext` without keeping `container` alive, letting the in-memory store be deallocated out from under the context — fixed by having test helpers return `ModelContainer` instead. Both are recorded in Important Decisions so they aren't rediscovered. Verified `swift test` (12 tests, all passing), `xcodebuild build`/`test` (both succeeding), and did a manual smoke test by running the built binary directly and confirming clean stdout/stderr across two consecutive launches (categories seed once, no duplicate-seed errors on relaunch).

**What remains:** Phases 3–8 of the product roadmap (see Remaining Work above), starting with Phase 3 (CSV import parsing engine).

**Exact next step:** Start Phase 3 — add a new `PETImport` package target to `Core/Package.swift` (depends on `PETModels`) containing: an encoding detector (UTF-8/BOM/Windows-1252 fallback), German number/date parsers, a quote-aware semicolon-delimited CSV parser, CAMT/MT940 header-alias column layouts, `ColumnMapping`, a row mapper producing `DraftTransaction` values, a hash-based duplicate detector, and an actionable `ImportError` type. No UI yet (that's Phase 4). Write `PETImportTests` against the three fixtures in `Fixtures/` (UTF-8 CAMT, Windows-1252 CAMT, MT940-style), covering: German decimal-comma/thousands parsing edge cases, DD.MM.YYYY date parsing, encoding auto-detection, quoted-field/embedded-semicolon CSV quirks (the MT940 fixture already has one deliberately), and duplicate detection. Verify with `swift test`, then a full `xcodebuild build`/`test` pass. After that milestone, follow the Ongoing Backup Workflow in `SECURITY.md` (update `CLAUDE.md`, run tests, review diff for sensitive data, commit, push).

**Command needed to continue:** From `PersonalExpenseTracker/`: `cd Core && swift build && swift test` for fast package-only iteration; `xcodebuild build -project PersonalExpenseTracker.xcodeproj -scheme PersonalExpenseTracker -destination 'platform=macOS'` and the equivalent `xcodebuild test …` for the full app once UI/pbxproj changes are involved. To sync with GitHub: `git status`, `git add -A`, `git commit -m "..."`, `git push`.

**Any user decision still required:** None. Proceed with Phase 3 as planned unless redirected.
