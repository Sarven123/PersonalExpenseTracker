# Security & Data-Protection Policy

PersonalExpenseTracker is a private, local-only personal finance application. This document
records the data-protection rules for this repository and the publishing policy for its
GitHub visibility. Every contributor/session (human or AI) working in this repo must follow
these rules.

## Repository visibility policy

- This repository **must remain PRIVATE** on GitHub at all times during normal development.
- It may only be switched to public after:
  1. A documented security review (see "Security review record" below) finds no outstanding
     issues, and
  2. The repository owner **explicitly confirms in writing** that they want it public.
- No process, script, or automated workflow may change visibility from private to public
  without that explicit confirmation. If asked to do so without confirmation, refuse and
  explain this policy.

## What must never be committed, pushed, or logged

- Passwords, API keys, access tokens, GitHub tokens, or any other credentials.
- Sparkasse (or any bank) login credentials — this app never asks for bank credentials in the
  first place, since it only imports locally-exported CSV files.
- Real IBANs, real account numbers, or real transaction data of any kind.
- Real Sparkasse (or any bank) CSV exports, account statements, or PDFs.
- Local SwiftData/Core Data stores, SQLite files (`*.sqlite`, `*.sqlite3`, `*.db`), or any
  other local database produced by running the app.
- Local backups produced by the app's own backup-export feature.
- `.env` files, certificates, signing assets (`*.p12`, `*.pem`, `*.mobileprovision`), or
  keychain files.
- Real usernames, home-directory paths, or other machine-identifying information in source,
  documentation, or commit messages.

All of the above are enforced via `.gitignore` (build products, user-specific Xcode state,
local databases, backups, real-bank-export filename patterns, and secret/credential file
patterns are all excluded). `.gitignore` explicitly re-includes `/Fixtures/**` since those
files are synthetic test data (see below) and are required for the import-parser test suite.

## Synthetic test data

`Fixtures/*.csv` contains **entirely fictional** Sparkasse-style CSV exports used only to test
CSV/CAMT/MT940 parsing, German date/number formats, and encoding handling. They are not, and
must never become, real bank data. Specifically:

- Merchant/payer names use Germany's conventional placeholder pattern (e.g. "Muster
  Arbeitgeber GmbH", "AOK Musterland" — "Muster" = "sample/example", equivalent to "Jane Doe"
  in English) or generic real-world merchant names (REWE, Netflix, dm-drogerie markt, Zalando,
  DB Vertrieb GmbH) used only as categorization-matching examples, the same way any finance
  app's documentation or test suite references well-known merchants.
- IBAN-formatted strings in the fixtures are invented or drawn from standard textbook IBAN
  examples (e.g. `DE89370400440532013000`, the IBAN example used throughout banking
  documentation worldwide) — they are not tied to any real account or person.
- Amounts, dates, and reference text are all invented.

If a future session ever needs additional fixtures, they must follow the same rule: clearly
fictional data only, never a real export.

## Ongoing backup workflow (every meaningful milestone)

1. Update `CLAUDE.md` (and this file, if the security posture changed).
2. Run the relevant build/tests where practical.
3. Inspect `git diff`/`git status` for anything matching the "never commit" list above.
4. Commit with a descriptive message.
5. Push to the private `main` branch on GitHub.
6. Record the commit hash, push result, and next step in `CLAUDE.md`.

Broken work is only committed if the commit message says so explicitly and `CLAUDE.md`
records the known issue — broken work is never silently pushed as if it were complete.

## Security review record

| Date | Reviewer | Files reviewed | Result |
|------|----------|-----------------|--------|
| 2026-09-20 | Claude Code (session) | All 27 files staged for the initial commit (see `git ls-files`) | No secrets, tokens, private keys, `.env` files, certificates, real CSV exports, PDFs, SQLite databases, or real transaction-like data found. `CLAUDE.md` was edited to remove one local absolute path (`/Users/<username>/...`) before committing. Fixtures confirmed synthetic (see above). **Repository kept PRIVATE.** |
| 2026-09-21 | Claude Code (session) | All 113 tracked files (`git ls-files`), plus a full scan of every commit reachable from any ref (`git log --all -p`) — not just the current tree, since a made-public repo exposes full history | Secret/credential scan (API keys, tokens, private-key headers, AWS/GitHub token patterns) across all history: **none found**. Real financial data scan: **none found** — every IBAN-shaped string in `Fixtures/*.csv` is either the standard textbook example IBAN, a clearly sequential/fabricated pattern, or a well-known published example, matching the existing documented rationale above; no real account numbers, bank credentials, CSV exports, or SQLite/database files anywhere in history. Signing/dependency check: ad hoc code signing only (`CODE_SIGN_IDENTITY = "-"`), no `DEVELOPMENT_TEAM`/provisioning profile, zero third-party dependencies — nothing proprietary or license-encumbered to disclose. **One real finding, since fully remediated**: the local macOS account username was embedded in a hardcoded absolute path in 4 places in `CLAUDE.md` (a reference to an external plans file, outside this repo) — a direct violation of this file's own "never commit a real username or home-directory path" rule, missed by the 2026-09-20 review because it was introduced afterward. Fixed in the current file (reworded to a `~/`-relative path), and then — with the repository owner's explicit confirmation, since this is a destructive operation — the entire git history was rewritten with `git filter-repo --replace-text` to replace every occurrence of the username with a redaction placeholder across every past commit, followed by a force-push to `origin/main`. A full backup of the pre-rewrite repository (working tree + `.git`) was made before the rewrite. Post-rewrite, `git log --all -p | grep` for the username across all history returns zero matches. Commit history still permanently records the repo owner's real git commit email (`oneg45225@gmail.com`) — expected/normal for a personal GitHub repo and not a "never commit" item under this policy, but worth the owner's awareness since it becomes publicly visible once the repo is public. No `LICENSE` file exists — not a security issue, but worth adding for a public repo. **Recommendation: safe to publish** — no outstanding issues found. **Repository made PUBLIC** per the owner's explicit confirmation. |

## Before ever going public

Any future request to make this repository public must be preceded by a fresh review that
explicitly answers:

- Which files were reviewed (full list or `git ls-files` output).
- Secret/privacy scan result (patterns checked and outcome).
- Dependency and license concerns (as of this writing: zero third-party dependencies).
- Whether real financial data was confirmed absent.
- Whether any local paths, tokens, keys, signing assets, or user-specific settings remain.
- A recommendation: remain private, or safe to publish.

The repository stays private unless the owner explicitly confirms, in writing, that they want
it public **after** reading that review.
