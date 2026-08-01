# Changelog

All notable changes to Outbox are documented here.

## Unreleased

- Add Tools settings tab: import your published posts from Mastodon/Bluesky
  (smart merge by content, dupes kept for review), and a Photos-style de-duper
  that only merges with per-group confirmation.
- Snapshot the upstream post a reply targets into `in_reply_to_snapshot`
  frontmatter, with a quoted preview card in the show view and reply form.
- "Update Copies" pushes edits of published posts to networks that allow it
  (Mastodon); networks that don't record their live text as per-copy divergence.
- Display settings: hide avatars in post rows, date format choice, post content
  size, Open in Finder for the archive folder.
- Keyboard: ⇥ between columns again, ⌘R reply, ⌘E edit, ⌘←/→ column moves,
  ⌘⌥1–4 sidebar groups, ⌃0–9 filter and account shortcuts.
- Post show view: content-first layout with whitespace instead of separators.

- Remodel the archive around single Posts: one canonical file per post at
  `YYYY/MM/DD/slug-N.md`, with network copies recorded in a `syndication`
  frontmatter list and pending destinations in `targets`. Failed targets stay
  pending, so re-publishing retries exactly what's missing. Existing per-copy
  archives migrate automatically on launch.
- Replies split into `in_reply_to` (someone else's post, by URL) and
  `in_reply_to_post` (your own post — thread continuations resolve the right
  parent per network automatically).
- Post rows show one row per Post with all its endpoint pairs; the post view
  gains Copies and pending sections, including per-copy sent text when it
  differed from the canonical body.

- Initialize repository with README, TODO, scripts, and project scaffolding.
- Add `OutboxKit` Swift package: `PostFile` (Markdown + YAML frontmatter),
  `Slug`, `PostStore` (`Network/Account/YYYY/MM/DD/slug-N.md` archive),
  `CharacterCount` per-network rules.
- Add adapters: Mastodon (`POST /api/v1/statuses`), Bluesky (createSession +
  createRecord with link facets), Threads (no-op stub).
- Add `Publisher`: file-first orchestration — the local file is always written
  before any network call and updated with the receipt after.
- Add `MastodonOAuth` (app registration, authorize, token exchange, verify),
  `KeychainStore`, `AccountsRepository`.
- Add multiplatform SwiftUI app (macOS/iOS/iPadOS 26.5, XcodeGen): composer with
  per-endpoint chips and live character counts, account management with OAuth
  (Mastodon) and app password (Bluesky) flows, publish results sheet, archive
  folder setting with security-scoped bookmarks.
- Add PKCE (S256) to the Mastodon OAuth flow.
- Fetch each Mastodon instance's real character limit at connect time and use it
  in the composer.
- Sign macOS builds with the development team so the data-protection Keychain
  works; fall back to the login keychain in unsigned builds.
- Show the real OSStatus message in Keychain errors.
- Make text in the add-account modals selectable.
- Fix the publish results sheet rendering no rows; make its text selectable.
- Give adapter errors readable descriptions (HTTP status + server message).
- Keychain reads/deletes now check both the data-protection and login keychains.
- Rebuild the app as a Mail-style three-column UI: accounts sidebar, searchable
  posts list, and a detail column that shows a post (status, permalinks,
  extracted hashtags/mentions/links) or hosts the new/edit form with a
  danger-zone delete.
- Add drafts: save without publishing, publish later in place.
- Add replies: paste a Mastodon/Bluesky post URL to create a proper reply
  (resolved via Mastodon search / atproto getRecord with thread-root
  propagation); a Reply button on published posts prefills it.
- Add `in_reply_to` and `composition` frontmatter fields.
- Replace SF Symbol placeholders with real Bluesky, Mastodon, and Threads brand
  glyphs (Simple Icons SVGs, template-rendered so they tint like symbols).
- Add favoriting within Outbox (never sent to networks): star toggle on the
  post view, `favorite: true` frontmatter, star pill filter, and Favorites
  sidebar rows globally and per account.
- Move accounts and archive-folder settings into a proper Settings window
  (⌘, on macOS, General + Accounts tabs); account removal now asks for
  confirmation and explains that archived files stay on disk.
