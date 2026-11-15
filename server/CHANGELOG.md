# Changelog

## 0.1.0
- Accounts, authenticator confirmation, sessions (step 3a).

## 0.2.0
- Event log and attachments for encrypted sync (step 3b). Sync needs the authenticator set up.

## 0.3.0
- Recovery (step 3c): the library key's passkey and recovery-code copies (locked), password reset
  with an authenticator code, change password, change email.
- Daily database backups with a retention setting, and a `restore` command.
- Admin commands: `stats`, `list`, `suspend`, `unsuspend`, `delete`, `backup`, `health`.
- On start-up it says who can connect and, on `--host 0.0.0.0`, which addresses to use.
- A Dockerfile and `compose.yaml` (repository root).
