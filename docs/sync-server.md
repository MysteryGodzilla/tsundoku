# Running a Tsundoku sync server

Sync is optional. Tsundoku works fully on one phone without a server or an account. A sync server
keeps the same library on more than one device: a phone and a tablet, say, or two phones in one
household (each person has their own account).

**What the server holds:** email addresses, when each account was made and last used, how much it
stores, and locked boxes. Every book, note, rating and photo is locked on the phone before it's
sent, with a key the server never gets. Whoever runs the server can't read anyone's library,
reset anyone's password or open a backup. That's by design (see [phase3-design.md](phase3-design.md)).

It's one small program with its own database file. It runs happily on an always-on home computer,
a NAS or a Raspberry Pi (64-bit).

## 1. Choose how the phones will reach it

| | Home network only | Tailscale | The internet, with https |
|---|---|---|---|
| Syncs | Only when the phone is on your home Wi-Fi | Anywhere | Anywhere |
| Setup | Easiest | Easy (a free Tailscale account) | Most work: a domain name, port forwarding, a proxy |
| Open to the internet | No | No | Yes |
| Connection | Plain http (the app warns) | Private: Tailscale locks it, or use its https | https |

- **Home network only.** The easiest, and nothing is exposed to the internet. Changes made away
  from home wait safely on the phone and go through the next time Tsundoku is open on your home
  Wi-Fi. The app only mentions it if sync hasn't reached the server for a week.
  - **The catch:** the connection is plain http. Books stay locked either way, but someone else on
    the same network could catch a sign-in and use it to change or delete the synced copy (the
    books on the phone stay safe). **We don't recommend plain http** unless you trust everyone on
    your network. The app warns about it and asks you to agree before it carries on.
- **Tailscale** ([tailscale.com](https://tailscale.com)) puts the phone and the server on a private
  network of your own, wherever they are. The connection is locked by Tailscale even though the
  address starts with `http://` (the app can't tell, so it still shows its plain http warning).
  For a proper https address, use Tailscale's own https (see 5).
- **The internet, with https:** a domain name pointing at your home, a reverse proxy such as
  Caddy in front of the server, and ports 80 and 443 forwarded on your router. See 5.

## 2a. Install with Docker (recommended)

Docker is the usual way to run home-lab services. Install
[Docker Desktop](https://docs.docker.com/get-started/get-docker/) (Windows, macOS) or Docker
Engine (Linux), then:

```sh
git clone https://github.com/MysteryGodzilla/tsundoku.git
cd tsundoku
docker compose up -d --build
```

The first build takes a few minutes. Then:

- `docker compose ps` shows `tsundoku` as running (and "healthy" after a minute).
- `docker compose logs tsundoku` shows what it's doing.
- The database and its daily backups live in the Docker volume `tsundoku-data`.
- To update: `git pull`, then `docker compose up -d --build` again. Accounts and data are kept.
- To stop it: `docker compose stop` (or `docker compose down`, which keeps the volume).

Inside the container the server listens on every network (`--host 0.0.0.0`) so that Docker can
pass connections in. Which networks outside can reach it is set by `ports` in
[compose.yaml](../compose.yaml): `"8797:8797"` lets phones on your home network connect to this
computer's address. Behind a proxy on the same computer, use `"127.0.0.1:8797:8797"`.

## 2b. Or run the program directly

Install [Dart](https://dart.dev/get-dart) 3.14 or newer, then build it:

```sh
git clone https://github.com/MysteryGodzilla/tsundoku.git
cd tsundoku/server
dart pub get
dart build cli
```

The program is in `build/cli/<system>/bundle/`. Keep its `bin` and `lib` folders together; you
can move the `bundle` folder anywhere. Start it:

```sh
bundle/bin/tsundoku_server serve --host 0.0.0.0 --db /srv/tsundoku/tsundoku.db
```

- **`--host`** says who can connect. The default, `127.0.0.1`, means only this computer: right
  behind a proxy, but phones can't reach it. **`0.0.0.0`** means phones on your home network can
  too. It listens on every network the computer is on, so use it on a computer that stays at home
  (on a laptop that travels, use Tailscale instead).
- When it starts, it lists the addresses to type into the app.
- `--port 8797` is the default. `--backups <folder>` and `--keep-days 14` set the daily backups
  (see 6); `--backups off` turns them off.
- **Firewall:** let the port in. Windows asks the first time (allow "Private networks"); on
  Ubuntu, `sudo ufw allow 8797/tcp`.
- **Keep it running** after a restart: on Linux, a systemd service such as

  ```ini
  # /etc/systemd/system/tsundoku.service
  [Unit]
  Description=Tsundoku sync server
  After=network-online.target

  [Service]
  User=tsundoku
  ExecStart=/opt/tsundoku/bundle/bin/tsundoku_server serve --host 0.0.0.0 --db /srv/tsundoku/tsundoku.db
  Restart=on-failure

  [Install]
  WantedBy=multi-user.target
  ```

  after making its user and folder (`sudo useradd --system tsundoku`,
  `sudo mkdir -p /srv/tsundoku`, `sudo chown tsundoku /srv/tsundoku`), then
  `sudo systemctl enable --now tsundoku`. On Windows, Task Scheduler ("At startup") or a service
  wrapper such as NSSM.

## 3. On a home network

1. **Find the server computer's address.** Windows: `ipconfig` ("IPv4 Address"). Linux:
   `hostname -I`. macOS: `ipconfig getifaddr en0`. It usually starts with `192.168.` or `10.`.
2. **Give it a fixed address** in your router's settings (often called a "DHCP reservation"), or
   the address can change and the phones lose the server.
3. **In the app:** Settings, then "Use a sync server". Type the address and port, like
   `10.0.0.20:8797`. The app tries https first; when it finds a plain http server it explains the
   risk and asks you to agree.

## 4. In the app

- **Create an account** on the first phone: the server address, an email address (it's only the
  login name; the server sends no email) and a password of at least 10 characters.
- **Authenticator app:** next, Tsundoku is added to an authenticator app (Google Authenticator,
  Microsoft Authenticator, Aegis and so on). Its 6-digit codes reset a forgotten password. Sync
  starts once this is done.
- **If you forget your password:** then save a passkey in your Google account (a new phone opens
  the library with your fingerprint), or make a recovery code to keep somewhere safe. Without one of
  them, a forgotten password means starting the synced copy again from the books on a phone.
- **Other devices:** sign in with the same email and password.

## 5. https (recommended)

**With Tailscale:** install Tailscale on the server computer and on each phone, signed in to the
same account. Turn on HTTPS certificates in the Tailscale admin console (DNS settings), then on
the server:

```sh
tailscale serve --bg 8797
```

`tailscale serve status` shows the https address to type into the app. Only your own devices can
reach it, and the server can stay on `--host 127.0.0.1`.

**With a domain and Caddy:** point a name (like `books.example.com`) at your home, forward ports 80
and 443 on your router to the server computer, and run [Caddy](https://caddyserver.com) with this
`Caddyfile`:

```
books.example.com {
    reverse_proxy 127.0.0.1:8797
}
```

Caddy gets and renews the https certificate itself. Run Tsundoku with `--host 127.0.0.1` (or the
`"127.0.0.1:8797:8797"` port line with Docker), so it's only reachable through Caddy.

## 6. Backups

- The server copies its database once a day into `backups/` beside it, keeping 14 days
  (`--keep-days` changes that). A copy holds exactly what the server does: accounts and locked boxes.
- Copy the `backups` folder somewhere else as well (another disk, or cloud storage), in case the
  computer dies. With Docker, `docker compose cp tsundoku:/data/backups ./tsundoku-backups` does it.
- **To restore:** stop the server, put a copy back, start it again:

  ```sh
  tsundoku_server restore backups/tsundoku-2026-11-14-0300.db --db tsundoku.db
  ```

  With Docker:

  ```sh
  docker compose stop
  docker compose run --rm tsundoku restore /data/backups/tsundoku-2026-11-14-0300.db --yes
  docker compose start
  ```

  The database it replaces is kept beside it, named `tsundoku.db.before-restore-…`.
- When an account is deleted, older backups still hold its locked copy until they age out (14
  days by default). Nobody can open it without that person's password, passkey or recovery code.

## 7. Admin commands

Run them on the server computer, with the same `--db` as the server (with Docker:
`docker compose exec tsundoku tsundoku_server <command>`, no `--db` needed).

| Command | What it does |
|---|---|
| `tsundoku_server stats` | Accounts, storage, database size, last backup |
| `tsundoku_server list` | Every account: email, created, last seen, how much it stores. Never library data |
| `tsundoku_server suspend <email>` | Signs the account out everywhere and stops it signing in or syncing. Nothing is deleted |
| `tsundoku_server unsuspend <email>` | Lets it sign in again |
| `tsundoku_server delete <email>` | Deletes the account and everything it synced (asks first; `--yes` skips that) |
| `tsundoku_server backup` | Makes a backup copy now |
| `tsundoku_server restore <copy>` | Puts a copy back (stop the server first) |
| `tsundoku_server health` | Exits with 0 if the server on this computer answers (Docker uses it) |

There's no admin web page, and no admin command can read a library or reset a password.
