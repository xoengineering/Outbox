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
- `script/setup` — install tools, generate `Outbox.xcodeproj` (XcodeGen), and
  create `Local.xcconfig` from the example. Set `DEVELOPMENT_TEAM` in it to your
  Apple Developer Team ID; it's gitignored, so no one's team ID is in the repo.
- `script/test` — run the OutboxKit test suite
- `script/build [macos|ios]` — build the app
- `script/lint` / `script/format` — swift format + SwiftLint
- `script/run` — build and launch the macOS app
- `script/run ios` — build, install, and launch in the iOS Simulator.
  Takes an optional simulator name: `script/run ios "iPad Pro 11-inch (M5)"`.
  Only iOS 26 simulators are eligible, since the deployment target is 26.5

To run on a physical iPhone or iPad, open `Outbox.xcodeproj` in Xcode, pick the
device as the destination, and Run. The device needs Developer Mode enabled
(Settings → Privacy & Security → Developer Mode) and `DEVELOPMENT_TEAM` set in
`Local.xcconfig`.

## License

MIT — see [LICENSE.md](LICENSE.md).

## File format

One file per Post — the canonical copy you own. Each network it's published
to is recorded as a syndicated copy (POSSE / LOCKSS).

```sh
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
