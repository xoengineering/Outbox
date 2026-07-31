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
