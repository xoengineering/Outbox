# TODO

Outbox: a write-only social media publishing app for macOS, iOS, and iPadOS.
Post to socials without the distraction of feed reading. Every post is saved
locally as a plaintext Markdown file first; syndication to each network is a
separate step (POSSE).

Minimums: macOS/iOS/iPadOS 26.5, Swift 6.3+, SwiftUI, Swift Testing.

---

## Open Questions

Decisions I made unilaterally to keep moving — flag anything you want changed.

1. **Bundle ID**: `engineering.xo.Outbox` (confirmed). The Mastodon app-registration
   website is `https://xo.engineering` — inferred from the bundle ID; confirm the domain.
2. **Bluesky auth**: v1 uses app passwords (Settings → App Passwords on Bluesky),
   stored in Keychain. This bends the "never ask username/password" rule — full
   atproto OAuth (PKCE + DPoP + PAR) is a heavy lift I deferred. Upgrade later?
3. **Folder layout**: the TODO prose said flat `YYYY-MM-DD-slug-N.md` filenames but
   the examples showed nested `YYYY/MM/DD/slug-N.md`. I followed the examples (nested).
4. **Nth-of-day counter**: `-N` is the Nth post of that day for that account
   (count of existing `.md` files in the day folder + 1), not the Nth with the same slug.
5. **Day boundaries**: file paths use the user's local timezone for YYYY/MM/DD;
   frontmatter timestamps are stored in UTC (`...Z`).
6. **One file per endpoint**: publishing one composition to 3 accounts writes 3 files
   (one per network/account), each carrying its own receipt (id/url/published_at).
   Alternative: one canonical file + syndication links. I followed your examples.
7. **Mastodon counting**: counts Unicode codepoints after replacing each URL with 23
   characters and stripping mention domains — matches Mastodon's documented rules.
   Bluesky counts grapheme clusters (300); Threads flat 500.
8. **Threads**: stub adapter that no-ops (saves the file locally, sends nothing);
   UI shows the endpoint. Real implementation would use the Threads API
   (developers.facebook.com/docs/threads) — needs a Meta app registration.
9. **Frontmatter schema**: `network`, `account`, `created_at`, then after publish
   `published_at`, `id`, `url`. Kept minimal on purpose.
10. **Mastodon OAuth uses PKCE (S256)**. Instances older than 4.3 ignore the PKCE
    params, which is harmless — but I haven't verified against a real old instance.
11. **Xcode project via XcodeGen** (`project.yml` → `script/generate`), so the
    `.xcodeproj` is gitignored and regenerable.
12. **"Private" status**: the spec mentioned private/published/draft. Files currently
    derive draft vs published from `published_at`. Is "private" a visibility value
    (Mastodon private posts) or a local-only "never publish" flag?
13. **Editing published posts** edits the local file only (remote posts aren't
    updated — Mastodon supports edits, Bluesky doesn't). The reply-URL field is
    disabled when editing published posts.
14. **Reply button targets that post's account only** and prefills its permalink.
    Cross-network threaded follow-ups via `composition` siblings are Milestone 4.
15. **iPhone/iPad UX**: the split view collapses on compact widths but compose-in-
    third-column needs a dedicated push/sheet flow on iPhone. Mac-first for now.

---

## Milestone 1 — Core (done)

- [x] `OutboxKit` Swift package, testable from CLI (`script/test`)
- [x] `PostFile`: Markdown + YAML frontmatter, parse (Yams) + byte-stable serialize
- [x] `Slug` derivation from content
- [x] `PostStore`: `<base>/<Network>/<account>/<YYYY>/<MM>/<DD>/<slug>-<N>.md`
- [x] `CharacterCount`: per-network rules + limits
- [x] `MastodonAdapter`: `POST /api/v1/statuses` (Bearer token)
- [x] `BlueskyAdapter`: createSession + createRecord with link facets (UTF-8 byte offsets)
- [x] `ThreadsAdapter`: no-op stub
- [x] `Publisher`: file-first orchestration; per-target failures isolated
- [x] `MastodonOAuth`: app registration, authorize URL, token exchange, verify
- [x] `KeychainStore` (data-protection keychain) + `AccountsRepository` (JSON)

## Milestone 2 — App shell (in progress)

- [ ] XcodeGen multiplatform target (macOS + iOS/iPadOS 26.5)
- [ ] Composer: text editor + per-endpoint toggle chips with live character
      count/limit per account, over-limit warning blocks publish to that endpoint
- [ ] Accounts screen: add/remove Mastodon (OAuth via ASWebAuthenticationSession,
      `outbox://oauth/mastodon` callback) and Bluesky (app password) accounts
- [ ] Threads visible in UI as stub ("saves locally only")
- [ ] Settings: archive base folder picker (default `~/Documents/Outbox`),
      security-scoped bookmark so sandboxed access survives relaunch
- [ ] Publish flow: results sheet per endpoint (link to remote post + local file)
- [ ] App sandbox ON, entitlements: network client, user-selected file read/write

## Milestone 2.5 — Three-column app (done 2026-07-31)

- [x] Mail.app-style NavigationSplitView: Accounts | Posts | Post
- [x] Sidebar: All Posts + per-account filtering; search field on the posts list
- [x] Post show view: status badge, permalinks, extracted #hashtags/@mentions/URLs
- [x] Post form in third column (new + edit), danger-zone delete with confirmation
- [x] Drafts: save without publishing, publish later in place
- [x] Replies: paste a Mastodon/Bluesky post URL → proper reply
      (Mastodon `/api/v2/search` resolve; Bluesky resolveHandle + getRecord,
      thread root propagated). Reply button on published posts prefills it.
- [x] `composition` frontmatter ID linking sibling files from one crosspost
- [x] `in_reply_to` frontmatter field

## Milestone 3 — Robustness

- [x] Mastodon: fetch instance config (`/api/v2/instance`) to learn real character
      limit per account; store as `Account.maximumCharacters`
- [x] Mastodon PKCE (S256, RFC 7636 known-answer tested)
- [ ] Bluesky: session refresh (reuse `refreshJwt` instead of new session per post)
- [ ] Retry/queue: posts that fail to syndicate stay drafts; re-publish from file
- [ ] Drafts browser: list local archive, open file in editor, publish later
- [ ] Reveal in Finder / Files.app
- [ ] Error surfaces: rate limits, dead instances, expired tokens (re-auth prompt)
- [ ] iCloud Drive-safe file writing (coordinate if base folder is in iCloud)

## Milestone 3.5 — Single-Post model (done 2026-07-31)

- [x] One canonical file per Post: `YYYY/MM/DD/NN-slug.md` (zero-padded Nth of
      day, so folders list chronologically); network copies live in
      frontmatter (`syndication` list; `targets` = destinations still owed a copy)
- [x] Per-copy `text` override records what was actually sent when it differed
- [x] Failed/pending targets stay in `targets` — re-publish retries exactly those
- [x] `in_reply_to` (external URL) vs `in_reply_to_post` (own-post path);
      thread continuations resolve per-network parents from the parent's copies
- [x] Automatic migration from the per-copy layout on launch (composition ID
      grouping, same-content-same-minute fallback, favorite survives merge)
- [ ] Import tool: pull already-published posts from sites into the archive
- [ ] De-dupe tool: find same-content posts across sites and merge into one Post

## Milestone 4 — More content types

- [ ] Media attachments with alt text (next up). Design:
      - Attachment files copied into the post's day folder next to the `.md`
        (`<slug>-<N>-1.jpg`), so the archive stays self-contained plaintext + assets
      - Frontmatter: `media:` list of `{file, alt}` entries
      - Mastodon: `POST /api/v2/media` (multipart) → `media_ids[]` on the status
      - Bluesky: `com.atproto.repo.uploadBlob` → `app.bsky.embed.images` with alt
      - Composer: attach via file picker, per-image alt text fields, previews
      - Limits per network (Mastodon 4 images; Bluesky 4 images ≤1MB — verify)
- [ ] Content warnings / spoiler text (Mastodon), labels (Bluesky)
- [ ] Cross-network thread follow-ups: use `composition` to find sibling files and
      reply per-network to each sibling automatically
- [ ] Quote posts

## Milestone 5 — More networks

- [ ] IndieWeb Micropub + IndieAuth — excavate packages from
      `z_Outbox_previously/Outbox 1` (add PKCE, inject transport, real compliance tests)
- [ ] Threads for real (Meta app review required)
- [ ] Blogging: WordPress, Tumblr, Ghost
- [ ] Email (newsletter-style; SMTP or provider APIs)
- [ ] Instagram (if ever possible)

## Milestone 6 — Ship

- [ ] App icon, name check, App Store metadata
- [ ] Direct distribution first (Developer ID + notarization), App Store after
- [ ] Sparkle or TestFlight story for updates
- [ ] Onboarding: first-run explains file-first philosophy

---

## Prior art notes (excavated 2026-07-31)

From `~/Developer/dark-energy/z_Outbox_previously`:

**Worth keeping**
- `Outbox 1/Micropub` (403 LOC) + `Outbox 1/IndieAuth` (252 LOC): genuinely working
  clients for Milestone 5. Need PKCE, URLSession injection, honest tests.
- `Outbox 1/test-server/server.rb`: Sinatra IndieAuth provider bootable from Swift
  tests (subprocess + poll-until-ready) — reusable harness pattern for fake servers.
- `Outbox 1/README.md`: product vision + curated spec links.
- `Outbox/Views/EditorView.swift`: DispatchSource file-watcher (small, correct).
- `.swift-format` config (already copied into this repo).

**Dead ends to avoid (lessons applied here)**
- Packages never wired into the app → the two halves never met. Wire early.
- In-memory singleton DataStore, `"drafts"` magic strings → untestable thrash.
- `ENABLE_APP_SANDBOX = NO` + bare folder path in UserDefaults → use
  security-scoped bookmarks instead.
- UI claiming "credentials stored securely" while discarding them. Never ship that.
- Zero Mastodon/Bluesky/network code existed in either attempt — all written fresh here.
- Inflated test claims (micropub.rocks "compliance" tests that assert
  `token.count > 0`). Re-verify against real servers.
