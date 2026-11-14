# For agents

Tsundoku: a private, offline-first catalogue of the books you own, built so you never buy one twice.
No code yet; the plan is in [docs/roadmap.md](docs/roadmap.md).

## Build and test
- TODO: set when the stack is chosen (roadmap, Phase 0).

## Layout
- `docs/`: the roadmap, decisions log and design notes.

## Conventions
- The roadmap's "Product rules" are fixed by the product owner. Technical choices can change if
  those rules still hold; record every change in the roadmap's decisions log with the date.
- Don't add anything the roadmap lists under "Never in scope".
- One branch per change. Run the tests that cover what you touched.
- Test data and examples use made-up names: alice, bob, `example.com`, `192.0.2.1`.
  Never real usernames, hosts, IP addresses or local paths.
- Never commit secrets, `.env` or local config; `.gitignore` lists what stays out.
- No AI attribution in commits or pull requests.
- User-facing text is plain, friendly English (Australian/British spelling: "colour",
  "catalogue"). No jargon in the app.
