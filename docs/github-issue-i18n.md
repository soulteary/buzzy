# GitHub Issue: Internationalization (i18n) Support

## Summary

Add full internationalization (i18n) support to Fizzy so that the application can be localized into multiple languages. This issue tracks the current state, remaining work, and implementation guidelines.

## Background

Fizzy currently uses Rails’ built-in I18n API with English as the default locale. Some views and flows already use `t()` for user-facing strings; many areas still contain hardcoded English text. This issue defines the i18n feature and outlines the path to complete localization.

## Current State

### Implemented

- **Rails I18n configuration** (`config/application.rb`):
  - `config.i18n.default_locale = :en`
  - `config.i18n.fallback_locales = [:en]`
- **Locale files** under `config/locales/`:
  - `en.yml` – root English strings (e.g. `hello`)
  - `en/boards.yml` – board-related strings (edit, new, columns, column menu)
  - `en/cards.yml` – card container, display (stamp, meta), steps, watches
  - `en/shared.yml` – shared UI (skip link, dialogs, colophon, welcome letter, columns)
  - `en/users.yml` – profile, email addresses, data export, theme, transfer, access tokens
  - `en/sessions.yml` – sign in, magic links, session menu
  - `en/signups.yml` – sign up, completion
  - `en/webhooks.yml` – index, new, edit, show, form actions
  - `en/notifications.yml` – settings, unsubscribe, push, email, system, install
  - `en/columns.yml` – choose, add card, no cards here, maximize/expand column
  - `en/tags.yml` – index (title, delete)
  - `en/reactions.yml` – new, reaction (add, delete)
  - `en/events.yml` – empty_days (no activity)
  - `en/account.yml` – join codes, exports, imports
  - `en/filters.yml` – toggle, added_by, closed_by, assigned_to, my shortcuts/settings/custom_views
  - `en/searches.yml` – close_search
  - `en/user_mailer.yml` – email_change_confirmation
  - `en/my.yml` – menus (shortcuts, settings, people, jump, custom_views, boards, accounts), access_tokens, pins
- **Views already using translations**: Card closure, board create/edit/columns, card display (stamp, meta), column add/maximize, users (edit, show, email, data export), sessions (new, starts), signups, webhooks (index, new, edit, show, form), tags, events empty_days, searches, reactions (partial), boards edit users, cards watches, user_mailer email_change_confirmation, notifications settings (system, install, browser platform-specific instructions), CONTRIBUTING.md i18n section.

### Not Yet Done

- **Locale selection**: No UI or persistence for user/account locale; app uses `I18n.default_locale` only. (Phase 3)
- **Coverage**: The following areas still contain hardcoded user-facing strings (see **Remaining tasks** below for a concrete checklist).
- **Additional locales**: Only `en` locale files exist; no other languages (e.g. `es`, `ja`) have been added. (Phase 4)
- **Validation/error messages**: Model and validation messages may still be default Rails/English.
- **Test env**: `config.i18n.raise_on_missing_translations = true` is not enabled in test (commented out in `config/environments/test.rb`).

## Proposed Scope

### Phase 1 – Foundation (current branch)

- [x] Extract card closure and related card container strings into `config/locales/en/cards.yml`
- [x] Use `t("cards.container.*")` in closure partials
- [x] Fix any misplaced keys (e.g. ensure `moves_to_not_now_suffix` lives under `cards.container`)
- [x] Add a short i18n section to CONTRIBUTING.md (where to add keys, naming conventions)

### Phase 2 – Full UI coverage

- [x] Audit all views, partials, and mailers for hardcoded user-facing strings
- [x] Move strings into appropriate locale files (`en/boards.yml`, `en/cards.yml`, `en/shared.yml`, and new files: users, sessions, signups, webhooks, notifications, columns, tags, reactions, events, account, filters, searches, user_mailer)
- [x] Ensure JavaScript/Stimulus user-visible strings are passed from the server where updated (e.g. bridge_title, turbo_confirm)
- [x] Use interpolation (`%{name}`, etc.) and `_html` suffix where HTML is required (e.g. users.data_exports.show.expired_html, welcome letter)

### Phase 3 – Locale selection (optional)

- [ ] Add a way to set locale (e.g. user preference, account setting, or request/session)
- [ ] Persist locale (e.g. on `User` or `Identity`) and set `I18n.locale` in a controller/middleware
- [ ] Document how to add a new locale (copy `en/` to `xx/`, translate, add to `available_locales` if desired)

### Phase 4 – Additional languages (optional)

- [ ] Add at least one non-English locale (e.g. `es`, `ja`) as a proof of concept
- [ ] Ensure date/time and number formatting use `I18n.l` / `I18n.localize` where applicable (e.g. `local_datetime_tag` already helps with dates)

## Remaining tasks (Phase 2 follow-up)

These views/partials had hardcoded English strings; completed items are checked.

### Notifications

- [x] `notifications/unsubscribes/show.html.erb` – title, thanks text, "Notification Settings", "Back to Fizzy"
- [x] `notifications/unsubscribes/new.html.erb` – "Unsubscribe now"
- [x] `notifications/settings/show.html.erb` – page title, "Boards"
- [x] `notifications/settings/_system.html.erb` – platform-specific instructions (many platform/OS strings)
- [x] `notifications/settings/_push_notifications.html.erb` – ON/OFF, "Turn ON…", "Help me fix this", "Not receiving notifications?", when_not_working
- [x] `notifications/settings/_install.html.erb` – install instructions (platform-specific)
- [x] `notifications/settings/_email.html.erb` – "Email Notifications", "Email me about new notifications..."
- [x] `notifications/settings/_browser.html.erb` – "Turn on notifications for…", browser-specific steps
- [x] `notifications/notification/_header.html.erb` – "Card number"
- [x] `notifications/index/*` – "New for you", "Mark all as read", "Previously seen", showing_recent
- [x] `notifications/index.html.erb` – page title, "Notification settings", home
- [x] `notifications/_tray.html.erb` – "Notification Settings", "Settings", "See more/older items", "Clear all", "Notifications", toggle aria-label

### Filters

- [x] `filters/settings/_toggle.html.erb` – "Close/Expand/Collapse filter options"
- [x] `filters/settings/_terms.html.erb` – "Filter these cards…"
- [x] `filters/settings/_tags.html.erb` – "Tagged…", "Filter…"
- [x] `filters/settings/_sorted_by.html.erb` – "Sort by…"
- [x] `filters/settings/_manage.html.erb` – "Clear all"
- [x] `filters/settings/_indexed_by.html.erb` – "Status…", "Filter by…", "Filter by status…"
- [x] `filters/settings/_creators.html.erb` – "Added by…", "Filter…"
- [x] `filters/settings/_closers.html.erb` – "Closed by…", "Filter…"
- [x] `filters/settings/_assignees.html.erb` – "Assigned to…", "Filter…", "No one"
- [x] `filters/_settings.html.erb` – "Toggle filters"
- [x] `filters/_filter_toggle.html.erb` – "Delete custom view", "Save custom view"

### My menu & access tokens

- [x] `my/menus/_shortcuts.html.erb` – "Shortcuts", "Golden cards", "Stalled cards", "Cards closing soon", "Added today", "Done today"
- [x] `my/menus/_settings.html.erb` – "Settings", "Account Settings", "My Profile", "All notifications", "Notification Settings", "Sign out"
- [x] `my/menus/_people.html.erb` – "Invite people"
- [x] `my/menus/_jump.html.erb` – "Close menu", "Assigned to me", "Added by me", "Nothing matches that filter"
- [x] `my/menus/_custom_views.html.erb` – "Custom views", "Create a custom view"
- [x] `my/menus/_boards.html.erb` – "Add a board"
- [x] `my/menus/_accounts.html.erb` – "Accounts"
- [x] `my/access_tokens/*` – page titles, "Read", "Read + Write", "Copy access token", "Generate…", "Cancel and go back", "Description", "Permission", "Created", "Edit this token", revoke_confirm
- [x] `my/pins/*` – "Toggle pins stack", "Pinned", "Un-pin this card"

### Other (optional)

- [x] **Prompts** – `app/views/prompts/**` checked; content is user data (card titles, etc.), not fixed UI strings; no i18n needed.
- [x] **Testing**: Enable `config.i18n.raise_on_missing_translations = true` in `config/environments/test.rb`

## Technical Notes

- **Where to add keys**: Prefer namespaced keys under `config/locales/en/`, e.g. `cards.container.edit`, `boards.new.page_title`.
- **Interpolation**: Use `t("key", name: value)` and `%{name}` in YAML.
- **HTML**: For HTML content use a key ending in `_html` and pass `_html: true` or use `.html_safe` only when the translation is trusted (e.g. `welcome_letter_intro_html` in `shared.yml`).
- **Testing**: Consider enabling `config.i18n.raise_on_missing_translations = true` in test to catch missing keys.
- **Production**: `config.i18n.fallbacks = true` is set so missing translations fall back to the default locale.

## Acceptance Criteria

- All user-facing strings in the areas targeted for the current phase are translated via `t()` and live in locale files.
- No new hardcoded English strings are introduced in those areas.
- Existing specs and system tests pass; new specs for critical i18n behavior are welcome (e.g. locale switching if Phase 3 is implemented).

## References

- [Rails I18n Guide](https://guides.rubyonrails.org/i18n.html)
- Current locale files: `config/locales/en/*.yml`
- Example usage: `app/views/cards/container/_closure.html.erb`, `app/views/cards/container/_closure_buttons.html.erb`
