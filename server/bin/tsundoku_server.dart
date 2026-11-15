/// The Tsundoku sync server and its admin commands. Run with no arguments for help.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as io;
import 'package:sqlite3/sqlite3.dart';
import 'package:tsundoku_server/tsundoku_server.dart';

const usage = '''
Tsundoku sync server $serverVersion

  tsundoku_server serve [options]        Run the server.
      --host 127.0.0.1                   Who can connect. 127.0.0.1: only this computer (use it
                                         behind an https proxy). 0.0.0.0: phones on your network too.
      --port 8797
      --db tsundoku.db                   The database file.
      --backups <folder>|off             Daily copies (default: a "backups" folder beside the database).
      --keep-days 14                     How long copies are kept.

  tsundoku_server stats                  Accounts, storage and backups.
  tsundoku_server list                   Every account: email, created, last seen, storage.
  tsundoku_server suspend <email>        Stop an account signing in or syncing (nothing is deleted).
  tsundoku_server unsuspend <email>
  tsundoku_server delete <email> [--yes] Delete an account and everything it synced.
  tsundoku_server backup                 Make a copy now.
  tsundoku_server restore <copy> [--yes] Put a copy back (stop the server first).
  tsundoku_server health [--port 8797]   Exit 0 if the server here answers (for Docker).

  The admin commands take --db and --backups too, to find the same files as the server.
''';

String _abs(String path) => p.normalize(p.absolute(path));

Never _fail(String message, [int code = 1]) {
  stderr.writeln(message);
  exit(code);
}

Future<void> main(List<String> args) async {
  final options = <String, String>{};
  final flags = <String>{};
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--yes' || a == '-y') {
      flags.add('yes');
    } else if (a == '--help' || a == '-h') {
      flags.add('help');
    } else if (a.startsWith('--')) {
      if (i + 1 >= args.length) _fail('$a needs a value.\n\n$usage', 64);
      options[a.substring(2)] = args[++i];
    } else {
      positional.add(a);
    }
  }
  if (positional.isEmpty || flags.contains('help')) {
    stdout.write(usage);
    exit(positional.isEmpty && !flags.contains('help') ? 64 : 0);
  }
  final command = positional.first;
  final dbPath = options['db'] ?? 'tsundoku.db';
  final backupsOpt = options['backups'] ?? p.join(p.dirname(_abs(dbPath)), 'backups');
  final keepDays = int.tryParse(options['keep-days'] ?? '14') ?? _fail('--keep-days needs a number.', 64);

  String arg(String what) => positional.length > 1 ? positional[1] : _fail('Which $what?\n\n$usage', 64);

  switch (command) {
    case 'serve':
      await _serve(dbPath, options['host'] ?? '127.0.0.1', int.tryParse(options['port'] ?? '8797') ?? _fail('--port needs a number.', 64),
          backupsOpt == 'off' ? null : backupsOpt, keepDays);
    case 'health':
      exit(await _health(int.tryParse(options['port'] ?? '8797') ?? 8797) ? 0 : 1);
    case 'restore':
      _restore(arg('copy'), dbPath, flags.contains('yes'));
    case 'stats' || 'list' || 'suspend' || 'unsuspend' || 'delete' || 'backup':
      if (!File(dbPath).existsSync()) _fail('No database at ${_abs(dbPath)}. Use --db to say where it is.');
      final store = Store.open(dbPath);
      final backups = backupsOpt == 'off' ? null : Backups(store, _abs(backupsOpt), keepDays: keepDays);
      final admin = Admin(store, backups: backups);
      try {
        switch (command) {
          case 'stats':
            admin.stats().forEach(stdout.writeln);
          case 'list':
            admin.list().forEach(stdout.writeln);
          case 'suspend' || 'unsuspend':
            stdout.writeln(admin.suspend(arg('email'), suspended: command == 'suspend'));
          case 'delete':
            final email = arg('email');
            if (!flags.contains('yes')) {
              if (!stdin.hasTerminal) _fail('Add --yes to delete without being asked.');
              stdout.write('Delete $email and everything it synced? This can\'t be undone. Type yes: ');
              if (stdin.readLineSync()?.trim().toLowerCase() != 'yes') _fail('Nothing deleted.');
            }
            stdout.writeln(admin.delete(email));
          case 'backup':
            if (backups == null) _fail('Backups are off (--backups off).');
            stdout.writeln('Saved ${backups.backupNow()}');
        }
      } on AdminProblem catch (e) {
        _fail(e.message);
      } finally {
        store.close();
      }
    default:
      _fail('Unknown command "$command".\n\n$usage', 64);
  }
}

Future<void> _serve(String dbPath, String host, int port, String? backupDir, int keepDays) async {
  final store = Store.open(dbPath);
  final api = TsundokuApi(store);
  final backups = backupDir == null ? null : Backups(store, _abs(backupDir), keepDays: keepDays);
  final server = await io.serve(api.handler, host, port);

  stdout.writeln('Tsundoku server $serverVersion is running on port ${server.port}.');
  stdout.writeln('  Database: ${_abs(dbPath)}');
  stdout.writeln(backups == null ? '  Backups: off' : '  Daily backups: ${_abs(backups.dir)} (kept $keepDays days)');
  if (host == '127.0.0.1' || host == 'localhost' || host == '::1') {
    stdout.writeln('  Only this computer can connect. To let phones on your home network connect, start it');
    stdout.writeln('  with --host 0.0.0.0. To reach it from anywhere, put it behind https (see docs/sync-server.md).');
  } else if (File('/.dockerenv').existsSync()) {
    stdout.writeln('  Running in Docker: in the app, use this computer\'s address and the port you published.');
  } else {
    final addresses = [
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4))
        for (final a in i.addresses)
          if (!a.isLoopback && !a.isLinkLocal) '${a.address}:${server.port}',
    ];
    if (addresses.isNotEmpty) {
      stdout.writeln('  In the app, use ${addresses.length == 1 ? 'this address' : 'one of these addresses'}:');
      for (final a in addresses) {
        stdout.writeln('    $a');
      }
    }
    stdout.writeln('  This is plain http: anyone on the same network could see sign-ins (never her books,');
    stdout.writeln('  which are locked on the phone). https is recommended; see docs/sync-server.md.');
  }

  Timer? daily;
  if (backups != null) {
    void check() {
      try {
        final made = backups.runIfDue();
        if (made != null) stdout.writeln('Backup saved: $made');
      } catch (e) {
        stderr.writeln('Backup failed: $e');
      }
    }

    check();
    daily = Timer.periodic(const Duration(hours: 1), (_) => check());
  }

  Future<void> stop(ProcessSignal _) async {
    daily?.cancel();
    await server.close();
    store.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(stop);
  if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(stop);
}

Future<bool> _health(int port) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/v1/health'));
    final res = await req.close().timeout(const Duration(seconds: 5));
    final body = await res.transform(utf8.decoder).join();
    return res.statusCode == 200 && (jsonDecode(body) as Map)['ok'] == true;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

/// Puts a backup copy back in place of the database. The server must be stopped.
void _restore(String copy, String dbPath, bool yes) {
  if (!File(copy).existsSync()) _fail('No file at $copy.');
  try {
    final check = sqlite3.open(copy, mode: OpenMode.readOnly);
    try {
      check.select('SELECT COUNT(*) FROM accounts');
    } finally {
      check.close();
    }
  } catch (_) {
    _fail('$copy doesn\'t look like a Tsundoku backup.');
  }
  if (!yes) {
    if (!stdin.hasTerminal) _fail('Add --yes to restore without being asked.');
    stdout.write('Make sure the server is stopped. Replace ${_abs(dbPath)} with $copy? Type yes: ');
    if (stdin.readLineSync()?.trim().toLowerCase() != 'yes') _fail('Nothing changed.');
  }
  final db = File(dbPath);
  if (db.existsSync()) {
    // Fold any pending writes into the file first, so the old database is kept whole.
    final old = sqlite3.open(dbPath);
    old.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    old.close();
    final now = DateTime.now();
    final aside = '$dbPath.before-restore-${now.millisecondsSinceEpoch}';
    db.renameSync(aside);
    stdout.writeln('The old database is kept as $aside');
  }
  for (final extra in ['$dbPath-wal', '$dbPath-shm']) {
    if (File(extra).existsSync()) File(extra).deleteSync();
  }
  File(copy).copySync(dbPath);
  stdout.writeln('Restored. Start the server again.');
}
