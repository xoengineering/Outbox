# Changelog

All notable changes to Outbox are documented here.

## Unreleased

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
- Move accounts and archive-folder settings into a proper Settings window
  (⌘, on macOS, General + Accounts tabs); account removal now asks for
  confirmation and explains that archived files stay on disk.
