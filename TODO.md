# TODO

Prompt
This is a brand new empty project.

We're making an app to publish to social media sites, but not to read/scroll through feeds.

# Sites

The first site I care about are:

- Mastodon (ActivityPub)
- Bluesky (atproto)
- Threads (ActivityPub/custom API)

Later I will care about:

- IndieWeb (MicroPub)
- Instagram (if possible)
- Blogging (Tumblr, Wordpress, ...)
- Email!

---

# Publish to file first

When 'publishing', first save to a file.
That way, the user/author always owns a copy of their content.
Then, 'publishing' to social media site is a separate step,
using the content from the content and formatting in a web/API request shaped for each endpoint.
In IndieWeb land, we call this POSSE (Publish on own site, syndicate elsewhere).
This also means that if a new site comes along, say "MySpace 3000",
then the user simply adds a new authed account to their app config to start crossposting or backfilling.

# File format on disk

Markdown + YAML frontmatter.

Folder/file structure.

Configurable base location:

~/Documents/Outbox/NetworkName/AccountName/YYYY-MM-DD-slug-NthOfDayCount.md

Examples:
~/Documents/Outbox/
~/Documents/Outbox/Mastodon/@veganstraightedge@ruby.social/2026/09/18/happy-bday-to-me-1.md
~/Documents/Outbox/Bluesky/@veganstraightedge.com/2026/09/18/happy-bday-to-me-1.md

# Auth

Store important credentials/tokens securely in Keychain.
OAuth whenever possible.
Never ask username/password directly.
