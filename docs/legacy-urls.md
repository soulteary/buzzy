# Legacy URLs and migration

This document lists deprecated or removed URL patterns and the canonical replacements. It is intended for users, integrations, and operators.

## Account prefix in URL (removed: numeric and base36)

- **Removed:** Account URL prefix that was a **numeric** ID (e.g. `/1/boards`, `/999888/boards`) or **base36** (25-character) ID. These no longer resolve; requests will 404.
- **Canonical:** Use the account’s **hyphenated UUID** as the path prefix, e.g. `/{uuid}/boards` where `{uuid}` is the account’s primary key in the form `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`.
- **How to get the new URL:** From the app, open the account (e.g. boards list); the browser URL is the canonical account URL. Alternatively use the account’s `slug` (e.g. in API or admin tools), which returns the path prefix including the hyphenated UUID.

## Card links (removed: global and collection-scoped)

- **Removed:**  
  - `GET /cards/:id` (card by number without board context)  
  - `GET /collections/:collection_id/cards/:id`  
  These routes have been removed and will 404.
- **Canonical:** Card URLs are always under a board, using the **user path** (recommended):  
  - `GET /users/:user_id/boards/:board_id/cards/:id`  
  Here `:user_id` is the board’s canonical user (e.g. creator), `:board_id` is the board ID, and `:id` is the card’s **number** within the account.
- **Migration:** Update bookmarks and links to use the board-scoped user path. Open the card from the board in the UI and use that URL.

## Legacy redirects still supported

The following legacy paths are still supported with a redirect to the canonical URL. You can switch to the canonical form at any time.

| Legacy path | Redirects to |
|-------------|--------------|
| `/user/:id` | `/users/:id` (user profile; **301**; `:id` is user UUID) |
| `/collections/:id` | `/{script_name}/boards/:id` (**302**; board by UUID; `script_name` is the current account prefix when present) |
| `/:account_slug/boards/:board_id` | `/users/:user_id/boards/:board_id` (**301**; `user_id` = board’s creator) |
| `/:account_slug/boards/:board_id/cards/:id` | `/users/:user_id/boards/:board_id/cards/:id` (**301**; `user_id` = board’s creator) |

## Summary

- **Account URLs:** Only hyphenated UUID prefix is supported. Numeric and base36 account prefixes 404.
- **Card URLs:** Use board-scoped paths only; `/cards/:id` and `/collections/.../cards/:id` 404.
- **User and board path renames:** `/user` → `/users` and `/collections` → `/boards` remain supported via redirect.
