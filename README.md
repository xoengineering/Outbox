# Outbox

Write only social media publishing app

For macOS, iOS, and iPadOS.
No Windows, Linux, or Android.

Post to socials without the distraction of feed reading. Every post is saved
locally first as a plaintext Markdown file with YAML frontmatter, then
syndicated to each network (POSSE).

## Networks

- Bluesky (app password)
- Mastodon (OAuth)
- Threads (stub — saves locally only, for now)

## Development

- macOS/iOS/iPadOS 26.5+, Swift 6.3+, SwiftUI, Swift Testing
- `script/setup` — install tools, generate `Outbox.xcodeproj` (XcodeGen)
- `script/test` — run the OutboxKit test suite
- `script/build [macos|ios]` — build the app
- `script/lint` / `script/format` — swift format + SwiftLint
- `script/run` — build and launch the macOS app

## File format

One file per Post — the canonical copy you own. Each network it's published
to is recorded as a syndicated copy (POSSE / LOCKSS).

```
~/Documents/Outbox/2026/09/18/01-happy-bday-to-me.md
```

```markdown
---
created_at: 2026-09-18T17:32:00Z
syndication:
  - network: mastodon
    account: "@you@instance.social"
    published_at: 2026-09-18T17:32:05Z
    id: "115234567890123456"
    url: https://instance.social/@you/115234567890123456
---

Happy bday to me. 🎂
```
