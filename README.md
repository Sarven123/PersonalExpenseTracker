# Personal Expense Tracker

A private, local-only personal expense tracker for macOS. Import your Sparkasse (Germany)
bank exports or add expenses by hand, get automatic categorization and recurring-payment
detection, and see where your money goes on a dashboard with interactive charts — all
without an account, a server, or a single network call.

## Highlights

- **100% local.** All data lives in a SwiftData store on your Mac. No accounts, no cloud
  sync, no analytics, no network entitlement at all — the app is architecturally incapable
  of making a network request.
- **Sparkasse CSV import.** Reads both CAMT and MT940-style exports, auto-detects UTF-8 vs.
  Windows-1252 encoding, handles German decimal-comma/thousands-dot number formatting and
  `DD.MM.YYYY` dates, and flags duplicates before anything is committed.
- **Transparent, local categorization.** A small rule engine suggests a category for each
  imported transaction from ~40 built-in rules plus rules it learns every time you correct
  a category yourself. Nothing is sent anywhere to make these suggestions.
- **Recurring/subscription detection.** Transactions from the same merchant at a consistent
  interval and amount are automatically flagged as recurring.
- **Dashboard with Swift Charts.** Current month vs. prior month, a category breakdown donut,
  a daily-spending trend line, a weekly summary, top merchants, and your recurring
  subscriptions — with interactive hover tooltips.
- **Filters, search, sort, export.** A searchable/sortable transaction table with filters
  (date range, category, merchant, type, source, transfers), CSV export of exactly what
  you're looking at, and an Insights view for category/merchant/month/subscription
  breakdowns.
- **Your data, exportable and deletable.** A one-click CSV backup of everything, and a
  "Delete All Local Data" option behind a confirmation dialog.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16 or later
- No external accounts, API keys, or third-party dependencies of any kind

## Getting Started

1. Clone the repository and open `PersonalExpenseTracker.xcodeproj` in Xcode. Xcode will
   resolve the local `Core` Swift package automatically — there's nothing else to install.
2. Select the `PersonalExpenseTracker` scheme and press Run (⌘R).
3. On first launch, 14 default categories and a starter set of merchant rules are seeded
   automatically. The Dashboard's empty state offers an optional "Load Demo Data" button if
   you want to see the app populated before importing your own transactions.

To build and test from the command line instead of Xcode's UI:

```sh
# Full app (build + the app-level test target)
xcodebuild build -project PersonalExpenseTracker.xcodeproj -scheme PersonalExpenseTracker -destination 'platform=macOS'
xcodebuild test  -project PersonalExpenseTracker.xcodeproj -scheme PersonalExpenseTracker -destination 'platform=macOS'

# Just the platform-agnostic Core package (faster iteration on non-UI logic)
cd Core
swift build
swift test
```

## Importing a Sparkasse export

From Sparkasse's online banking, export your account's transactions (*Umsätze*) as either
a **CSV-CAMT** or **CSV-MT940** file. In the app, choose **Import CSV** from the Transactions
toolbar, the empty-state button, or ⌘I, then pick the file. You'll see:

1. What the app detected (CAMT vs. MT940-style, encoding, any rows it couldn't parse).
2. Which rows look like duplicates of transactions you already have, with the option to
   import any of them anyway.
3. A summary once the import completes.

Imported transactions are auto-categorized where a rule matches; anything left uncategorized
shows up under the "Uncategorized Only" filter for you to review and correct — each
correction teaches the app a new rule for next time.

The app never asks for, stores, or transmits your online banking credentials. It only ever
reads a CSV file you've already exported yourself.

## Architecture

The codebase is split into a platform-agnostic Swift package (`Core/`, so the shared logic
could support an iOS companion app later with minimal rework) and a thin macOS app shell:

```
PersonalExpenseTracker/
├── App/macOS/            App entry point, window/menu chrome, sidebar — AppKit-facing glue only
├── Core/                 Local Swift package "PETCore"; all real logic lives here
│   └── Sources/
│       ├── PETModels/            SwiftData schema (ExpenseCategory, ExpenseTransaction, ...)
│       ├── PETImport/             Sparkasse CSV parsing (encoding, German number/date parsing,
│       │                          CAMT/MT940 layout detection, duplicate detection)
│       ├── PETCategorization/     Rule-based category suggestion, merchant normalization,
│       │                          recurring-transaction detection — all pure, no persistence
│       ├── PETExport/             CSV export formatting (German conventions, RFC 4180 quoting)
│       ├── PETRepositories/       SwiftData persistence + business rules (CRUD, seeding,
│       │                          import/export orchestration, analytics aggregation, filtering)
│       └── PETSharedUI/           SwiftUI views (Dashboard, Transactions, Insights, Settings,
│                                  Import wizard, Category/Merchant Rule managers) — no AppKit
├── Fixtures/              Fictional Sparkasse CSV samples used by the test suite
└── PersonalExpenseTracker.xcodeproj
```

Each layer is testable at the right level: parsing, categorization, and export logic are
pure functions tested without any database; repositories are tested against an in-memory
SwiftData store; the app target itself carries only a thin integration check. See
`CLAUDE.md` for the full build history and the reasoning behind specific design decisions —
it's the running engineering log this project was built from, phase by phase.

## Testing

The `Core` package has ~140 Swift Testing (`import Testing`) tests covering German CSV
parsing, encoding detection, categorization rules, duplicate detection, recurring detection,
analytics aggregation, filtering, and CSV export — run them with `swift test` inside `Core/`
for the fastest feedback loop, or `xcodebuild test` for the full app including its one
SwiftData-integration check.

## Privacy & Security

See [`SECURITY.md`](SECURITY.md) for the full policy. In short: this repository stays
private, real financial data is never committed to it, and the app itself has no network
entitlement — there is no code path by which your data could leave your Mac.

## Known Limitations

- CSV import supports Sparkasse's CAMT and MT940-style layouts only; there's no manual
  column-remapping UI if a different export format doesn't match either one.
- The Dashboard's "current vs. prior period" comparison is fixed to calendar months; there's
  no period picker yet.
- Recurring-transaction detection re-runs after each CSV import (or a demo-data load), not
  after every manual edit.
