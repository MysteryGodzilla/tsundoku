# Tsundoku server

The optional sync server. It stores accounts and locked boxes: it never receives a password and
can never read a library. Design: [docs/phase3-design.md](../docs/phase3-design.md).

- **Install and run it:** [docs/sync-server.md](../docs/sync-server.md) (Docker, or the program
  on its own; home network, Tailscale or https).
- Run while developing: `dart run bin/tsundoku_server.dart serve --db tsundoku.db` (only this
  computer can connect; add `--host 0.0.0.0` for phones on the home network).
- Build the program: `dart build cli` (into `build/cli/<system>/bundle/`, with its own SQLite).
- Admin commands: `stats`, `list`, `suspend`, `unsuspend`, `delete`, `backup`, `restore`,
  `health`. Run it with no arguments for help.
- Test: `dart test`
