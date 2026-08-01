# TODO

Outbox: a write-only social media publishing app for macOS, iOS, and iPadOS.
Post to socials without the distraction of feed reading. Every post is saved
locally as a plaintext Markdown file first; syndication to each network is a
separate step (POSSE).

Minimums: macOS/iOS/iPadOS 26.5, Swift 6.3+, SwiftUI, Swift Testing.

---

## Open Questions

Decisions made unilaterally to keep moving — flag anything you want changed.
(Answered ones are struck from the list as they're settled.)

1. **Mastodon app website** is `https://xo.engineering`, inferred from the bundle
   ID `engineering.xo.Outbox`. Confirm the domain is right.
2. **Bluesky auth uses app passwords**, not full atproto OAuth (PKCE + DPoP + PAR
   + hosted client metadata). You called this a fair deferral; revisit when the
   app has a public home for its client metadata JSON.
3. **"Private" status**: drafts vs published is derived from whether any copies
   exist. Is "private" a visibility value (Mastodon private/unlisted posts) or a
   local-only "never publish" flag? Nothing implements it yet either way.
4. **Character counting**: Mastodon counts codepoints with URLs at 23 and mention
   domains stripped; Bluesky counts grapheme clusters (300); Threads flat 500.
   Per-instance Mastodon limits are fetched at connect time.
5. **Mastodon PKCE (S256)** is always sent. Instances older than 4.3 ignore the
   parameters harmlessly, but that's untested against a real old instance.
6. **iPhone/iPad UX**: the split view collapses on compact widths, but
   compose-in-the-third-column needs a dedicated push/sheet flow on iPhone.
   Mac-first so far; iOS builds but is unexercised.
7. **⌘←/⌘→ are inactive while the editor has focus**, so the caret keeps
   line-edge navigation. Say if you'd rather they always move columns.
8. **Day boundaries**: file paths use your local timezone for `YYYY/MM/DD`;
   frontmatter timestamps are stored in UTC (`...Z`).

---

## Done

### Core kit (Milestone 1)

- [x] `OutboxKit` Swift package, testable from the CLI (`script/test`)
- [x] `PostFile`: Markdown + YAML frontmatter, parsed with Yams, byte-stable serialize
- [x] `Slug`, `CharacterCount` (per-network rules), `KeychainStore`, `AccountsRepository`
- [x] `Publisher`: file-first orchestration, per-target failures isolated
- [x] Adapters: Mastodon, Bluesky, Threads — all real, all fixture-tested

### App shell (Milestone 2)

- [x] XcodeGen multiplatform target (macOS + iOS/iPadOS 26.5), sandbox on,
      entitlements for network client + user-selected files
- [x] Composer with per-endpoint chips: live character counts against each
      account's real limit; over-limit blocks publishing to that endpoint
- [x] Accounts in Settings: Mastodon OAuth (ASWebAuthenticationSession,
      `outbox://oauth/mastodon`), Bluesky app password, Threads OAuth
- [x] Archive folder picker with security-scoped bookmarks; Open in Finder
- [x] Publish results sheet per endpoint, linking remote post and local file

### Three-column app (Milestone 2.5)

- [x] Mail.app-style NavigationSplitView: Accounts | Posts | Post
- [x] Sidebar: All Posts / Published / Drafts / Favorites, globally and per
      account; hand-rolled rows so expansion animates and the chevron centers
- [x] Posts column: search, filter pills (status, favorites, per network),
      full post text, avatar+network pairs, context menus
- [x] Post show view: content first, permalinks, copies, extracted
      #hashtags (clickable → filter) / @mentions / links, file path → Finder
- [x] Post form in the third column for new and edit, with discard confirmation

### Single-Post model (Milestone 3.5)

- [x] One canonical file per Post: `YYYY/MM/DD/NN-slug.md` (zero-padded Nth of
      day, so folders list chronologically); network copies live in frontmatter
      (`syndication` list; `targets` = destinations still owed a copy)
- [x] Per-copy `text` override records what was actually sent when it differed
- [x] Failed/pending targets stay in `targets` — re-publish retries exactly those
- [x] `in_reply_to` (external URL) vs `in_reply_to_post` (own-post path);
      thread continuations resolve per-network parents from the parent's copies
- [x] `in_reply_to_snapshot` keeps the upstream post you replied to (author,
      text, fetched_at), shown as a quoted card in the form and show view
- [x] Automatic migration from the old per-copy layout on launch

### Tools

- [x] Import published posts from Mastodon and Bluesky, one account or all, with
      live progress; smart merge by content, uncertain matches kept for review;
      imported replies carry their `in_reply_to`
- [x] De-duper (Settings → Tools): Photos-style candidate groups, Merge or Keep
      All per group, never automatic

### Media (Milestone 3.8)

- [x] Attachments with alt text: picker, thumbnails, per-file alt editing, remove;
      `media:` frontmatter; files stored beside the post (`01-slug-1.jpg`)
- [x] Mastodon upload (`POST /api/v2/media` → `media_ids`, alt as `description`)
- [x] Bluesky upload (`uploadBlob` → `app.bsky.embed.images` with alt)
- [x] Rendered in the show view with alt text beneath each image

### Editing and safety

- [x] "Update Copies" pushes edits upstream where allowed (Mastodon `PUT`);
      networks that can't edit record their live text as per-copy divergence
- [x] Favoriting within Outbox (`favorite: true`), never sent anywhere
- [x] Nothing hard-deletes: posts and their media move to the Trash

### Keyboard and settings

- [x] ⌘N new, ⌘R reply, ⌘E edit, Return edit, ⌘F search, ⌘⌥R reveal in Finder,
      ⌃⌘S sidebar, ⇥/⇧⇥ and ⌘←/⌘→ between columns, ⌘1/2/3 focus a column
- [x] j/k move selection, `.` favorites, ⌫ trash (⌘⌫ skips the confirmation);
      type-to-select suppressed so stray keys don't jump the list
- [x] ⌘⌥1–4 sidebar groups; ⌃0–3 status/favorite filters; ⌃4–9 network filters
- [x] Settings: avatars on/off, network icons on/off, monochrome icons, date
      format, post content size, archive folder

---

## Next

### Housekeeping

- [ ] Bump deployment targets 26.5 → 26.6 now that it's out: `project.yml`,
      `OutboxKit/Package.swift`, and the minimums line in this file and the README
- [ ] CI workflow running `script/cibuild` (lint, tests, macOS + iOS builds)

### Robustness

- [ ] Bluesky session refresh (reuse `refreshJwt` instead of a new session per post)
- [ ] Threads long-lived token refresh (`th_refresh_token`); they expire in ~60 days
- [ ] Per-network attachment validation before upload: counts (4 images) and
      Bluesky's ~1MB per-image ceiling. Right now an oversized image fails at the API
- [ ] Video attachments are accepted by the picker but untested end to end
- [ ] Importer doesn't backfill `in_reply_to` onto posts it already tracks —
      only newly created/merged ones get it
- [ ] Threads import (the API exposes your own posts; the importer skips Threads)
- [ ] Error surfaces: rate limits, dead instances, expired tokens → prompt to
      reconnect rather than showing a raw HTTP error
- [ ] iCloud Drive-safe file writing (coordinate if the archive lives in iCloud)
- [ ] Watch the archive folder for external edits and reload

### More content types

- [ ] Content warnings / spoiler text (Mastodon), self-labels (Bluesky)
- [ ] Cross-network thread follow-ups: reply to each sibling copy automatically
      from one composition, rather than one network at a time
- [ ] Quote posts
- [ ] Scheduled posts

### More networks

- [ ] IndieWeb Micropub + IndieAuth — excavate the packages from
      `z_Outbox_previously/Outbox 1` (add PKCE, inject transport, honest tests)
- [ ] Threads media, which needs Outbox to host files at a public URL
- [ ] Blogging: WordPress, Tumblr, Ghost
- [ ] Email (newsletter-style; SMTP or provider APIs)
- [ ] Instagram (if ever possible)

### Ship

- [ ] App icon (the asset catalog has an empty `AppIcon` placeholder)
- [ ] iPhone/iPad layout pass; the app builds for iOS but hasn't been run there
- [ ] Direct distribution first (Developer ID + notarization), App Store after
- [ ] Sparkle or TestFlight story for updates
- [ ] Onboarding: first run explains the file-first philosophy
- [ ] Threads needs Meta app review before anyone but you can use it

---

## Lessons already paid for

- **Mastodon scopes are per-resource.** `write:statuses` doesn't cover media;
  uploads need `write:media`. Reading your own posts needs `read:statuses`, and
  reply resolution needs `read:search`. Changing scopes means re-authorizing
  every existing token — hence the Reconnect button.
- **macOS `List` won't animate structural changes**, which is why the sidebar is
  hand-rolled rows in a `ScrollView`.
- **Text views eat Tab** before SwiftUI key handling, so field-to-field hops go
  through an AppKit event monitor (`TabHopModifier`).
- **Hierarchical shape styles** (`.primary`, `.background`) render as vibrant
  materials in some contexts and wash out; brand colors use concrete values.
- **The data-protection Keychain needs a real signing identity**, so local builds
  sign with the development team rather than ad-hoc.

## Prior art notes (excavated 2026-07-31)

From `~/Developer/dark-energy/z_Outbox_previously`:

**Worth keeping**

- `Outbox 1/Micropub` (403 LOC) + `Outbox 1/IndieAuth` (252 LOC): genuinely working
  clients for the IndieWeb milestone. Need PKCE, URLSession injection, honest tests.
- `Outbox 1/test-server/server.rb`: Sinatra IndieAuth provider bootable from Swift
  tests (subprocess + poll-until-ready) — reusable harness pattern for fake servers.
- `Outbox 1/README.md`: product vision + curated spec links.
- `Outbox/Views/EditorView.swift`: DispatchSource file-watcher, for watching the
  archive folder later.

**Dead ends avoided**

- Packages never wired into the app → the two halves never met. Wire early.
- In-memory singleton DataStore, `"drafts"` magic strings → untestable thrash.
- `ENABLE_APP_SANDBOX = NO` + a bare folder path in UserDefaults → use
  security-scoped bookmarks instead.
- UI claiming "credentials stored securely" while discarding them.
- Inflated test claims (micropub.rocks "compliance" tests asserting
  `token.count > 0`). Verify against real servers.
