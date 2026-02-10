# Buzzy

This file provides guidance to AI coding agents working with this repository.

## What is Buzzy?

Buzzy is a collaborative project management and issue tracking application built by 37signals/Basecamp. It's a kanban-style tool for teams to create and manage cards (tasks/issues) across boards, organize work into columns representing workflow stages, and collaborate via comments, mentions, and assignments.

## Development Commands

### Setup and Server
```bash
bin/setup              # Initial setup (installs gems, creates DB, loads schema)
bin/dev                # Start development server (runs on port 3006)
```

Development URL: http://buzzy.localhost:3006
Login with: david@example.com (development fixtures), password will appear in the browser console

### Testing
```bash
bin/rails test                    # Run unit tests (fast)
bin/rails test test/path/file_test.rb  # Run single test file
bin/rails test:system             # Run system tests (Capybara + Selenium)
bin/ci                            # Run full CI suite (style, security, tests)

# For parallel test execution issues, use:
PARALLEL_WORKERS=1 bin/rails test
```

CI pipeline (`bin/ci`) runs:
1. Rubocop (style)
2. Bundler audit (gem security)
3. Importmap audit
4. Brakeman (security scan)
5. Application tests
6. System tests

### Database
```bash
bin/rails db:fixtures:load   # Load fixture data
bin/rails db:migrate          # Run migrations
bin/rails db:reset            # Drop, create, and load schema
```

### Other Utilities
```bash
bin/rails dev:email          # Toggle letter_opener for email preview
bin/jobs                     # Manage Solid Queue jobs
bin/kamal deploy             # Deploy (requires 1Password CLI for secrets)
```

## Architecture Overview

### Multi-Tenancy (URL-Based)

Buzzy uses **URL path-based multi-tenancy**:
- Each Account (tenant) is identified in URLs by its **UUID** (same base36-encoded format as other IDs, 25 chars), e.g. `/{account_id}/boards/...`
- Legacy numeric slugs (e.g. `/1/boards/...`) redirect to the UUID URL for backward compatibility
- Middleware (`AccountSlug::Extractor`) extracts the account ID from the URL and sets `Current.account`
- The slug is moved from `PATH_INFO` to `SCRIPT_NAME`, making Rails think it's "mounted" at that path
- All models include `account_id` for data isolation
- Background jobs automatically serialize and restore account context

**Key insight**: This architecture allows multi-tenancy without subdomains or separate databases, making local development and testing simpler.

### Authentication & Authorization

**Passwordless magic link authentication**:
- Global `Identity` (email-based) can have `Users` in multiple Accounts
- Users belong to an Account and have roles: owner, admin, member, system
- Sessions managed via signed cookies
- Board-level access control via `Access` records

**Single-user-per-account (multi-account single-user)**:
- Each Account allows only one real user (plus system); enforced by `User#single_real_user_per_account`
- When `Current.account_single_user?` is true, board scope and visibility short-circuit to `Current.account.boards` (and `Board#accessible_to?` returns true for same-account user) to avoid unnecessary Access joins
- Join-by-code (invite to existing account) routes are disabled; `Identity::Joinable#join` still prevents adding a second user

**Permission boundary (single-user checks vs cross-account)**:
- Write operations (edit/delete, board and card admin, exports, user/role management) are scoped to **current account + current user** (or same-account admin/creator rules). Permission checks use `Current.user` and do not grant cross-account write.
- Cross-account support is **read/participate only**: viewing others' boards and cards, public boards, @mentions, comments, pin to own tray, notifications. These paths use `allow_unauthorized_access`, `find_board_by_fallback` (including `Current.identity.users` when `Current.user` is blank), `Current.user_before_fallback`, and `blob_accessible_to_current_identity?`. When adding new features, consider whether the action is write (stick to current user) or read/participate (may need identity-level or fallback logic).

**Forward Auth (optional)**: When a reverse proxy (e.g. [Stargate](https://github.com/soulteary/stargate)) has already authenticated the user, Buzzy can trust `X-Auth-Email` and related headers from trusted IPs or with a secret header. See [docs/forward_auth.md](../docs/forward_auth.md) for configuration and security requirements.

### Core Domain Models

**Account** → The tenant/organization
- Has users, boards, cards, tags, webhooks
- Has entropy configuration for auto-postponement

**Identity** → Global user (email)
- Can have Users in multiple Accounts
- Session management tied to Identity

**User** → Account membership
- Belongs to Account and Identity
- Has role (owner/admin/member/system)
- Board access via explicit `Access` records

**Board** → Primary organizational unit
- Has columns for workflow stages
- Can be "all access" or selective
- Can be published publicly with shareable key

**Card** → Main work item (task/issue)
- Sequential number within each Account
- Rich text description and attachments
- Lifecycle: triage → columns → closed/not_now
- Automatically postpones after inactivity ("entropy")

**Event** → Records all significant actions
- Polymorphic association to changed object
- Drives activity timeline, notifications, webhooks
- Has JSON `particulars` for action-specific data

### Entropy System

Cards automatically "postpone" (move to "not now") after inactivity:
- Account-level default entropy period
- Board-level entropy override
- Prevents endless todo lists from accumulating
- Configurable via Account/Board settings

### UUID Primary Keys

All tables use UUIDs (UUIDv7 format, base36-encoded as 25-char strings):
- Custom fixture UUID generation maintains deterministic ordering for tests
- Fixtures are always "older" than runtime records
- `.first`/`.last` work correctly in tests

### Background Jobs (Solid Queue)

Database-backed job queue (no Redis):
- Custom `BuzzyActiveJobExtensions` prepended to ActiveJob
- Jobs automatically capture/restore `Current.account`
- Mission Control::Jobs for monitoring

Key recurring tasks (via `config/recurring.yml`):
- Deliver bundled notifications (every 30 min)
- Auto-postpone stale cards (hourly)
- Cleanup jobs for expired links, deliveries

### Sharded Full-Text Search

16-shard MySQL full-text search instead of Elasticsearch:
- Shards determined by account ID hash (CRC32)
- Search records denormalized for performance
- Models in `app/models/search/`

### Imports and exports

Allow people to move data between Buzzy instances:
- Exports/Imports can be wirtten to/read from local or S3 storage depending on the config of the instance (both myst be supported)
- Must be able to handle very large ZIP files (500+GB)
- Models in `app/models/account/data_transfer/`, `app/models/zip_file`

**Disable export data**: Set `DISABLE_EXPORT_DATA=true` to turn off and hide all export functionality (account export and user data export). UI is hidden and export endpoints return 404. See `Buzzy.export_data_enabled?` in `lib/buzzy.rb`.

**Hide emails**: Set `HIDE_EMAILS=true` to hide user email addresses across the UI (profile, account settings, board access, magic link hint, API). Emails are replaced with a placeholder (e.g. `••••••@••••••.•••`). Does not affect mail delivery or login/signup form inputs. See `Buzzy.hide_emails?` and `display_email` helper in `lib/buzzy.rb` and `app/helpers/application_helper.rb`.

## Tools

### Chrome MCP (Local Dev)

URL: `http://buzzy.localhost:3006`
Login: david@example.com (passwordless magic link auth - check rails console for link)

Use Chrome MCP tools to interact with the running dev app for UI testing and debugging.

## Coding style

@STYLE.md
