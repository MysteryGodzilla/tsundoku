# Tsundoku server

The optional sync server. It stores accounts and locked boxes: it never receives a password and
can never read a library. Design: [docs/phase3-design.md](../docs/phase3-design.md).

- Run: `dart run bin/tsundoku_server.dart serve --db tsundoku.db --host 127.0.0.1 --port 8797`
- Test: `dart test`

Status: step 3a (accounts, authenticator, sessions). Sync, recovery, admin commands and the install
guide come in steps 3b and 3c.
