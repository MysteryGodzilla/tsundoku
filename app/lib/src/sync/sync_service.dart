/// Encrypted sync between devices (docs/phase3-design.md, step 3b). Optional: it does nothing
/// unless she has signed in to a sync server and set up the authenticator.
///
/// A sync pulls first, then pushes. Each change is a small event, locked with the library key
/// before it leaves the phone. Different fields edited on two devices simply merge; the same field
/// edited on both since they last synced, or a deletion against an edit, is put to her.
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart';

import '../account/account_service.dart';
import '../backup/backup_format.dart';
import '../books/library_repository.dart';
import '../books/models.dart';
import '../covers/cover_store.dart';
import '../db/database.dart';

/// A decision waiting for her, ready to show.
class SyncDecision {
  SyncDecision({required this.id, required this.kind, required this.bookTitle, required this.what, this.here, this.there});
  final int id;

  /// `field`, `deletedThere` (deleted on another device, changed here) or `deletedHere`.
  final String kind;
  final String bookTitle;

  /// What differs, in words ("Reading status").
  final String what;
  final String? here;
  final String? there;
}

const _fieldLabels = {
  'title': 'Title',
  'authors': 'Author',
  'isbn13': 'ISBN',
  'publisher': 'Publisher',
  'publishedDate': 'Published',
  'format': 'Format',
  'purchasedOn': 'Date purchased',
  'finishedOn': 'Date finished',
  'rating': 'Rating',
  'notes': 'Notes',
  'status': 'Reading status',
  'coverRef': 'Cover',
  'genres': 'Genres',
  'photo': 'Cover photo',
};

/// Fields carried by a `created` snapshot that merge like single changes.
const _snapshotFields = [
  'title', 'authors', 'isbn13', 'publisher', 'publishedDate', 'format', 'purchasedOn', 'finishedOn', 'rating', 'notes',
  'status', 'coverRef', 'genres',
];

class SyncService extends ChangeNotifier {
  SyncService({required this.library, required this.covers, required this.account, DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final LibraryRepository library;
  final CoverStore covers;
  final AccountService account;
  final DateTime Function() _now;

  AppDatabase get _db => library.db;

  bool syncing = false;
  DateTime? lastSyncAt;
  String? problem;
  DateTime? failingSince;
  int pending = 0;
  int decisions = 0;

  /// The last unexpected error, for tests and diagnostics (never shown to her as is).
  String? lastError;

  /// After about a day of failures she's told (a product rule: only if the problem persists).
  bool get problemPersists => failingSince != null && _now().difference(failingSince!) > const Duration(hours: 24);

  bool get ready => account.signedIn && account.state!.totpConfirmed && account.libraryKey != null;

  StreamSubscription<void>? _changes;
  Timer? _debounce;
  Timer? _every;

  /// Sync a few seconds after each change, and every few minutes while open.
  void start() {
    _changes ??= _db.tableUpdates(TableUpdateQuery.onTable(_db.changeLog)).listen((_) {
      _refreshCounts();
      if (!ready) return;
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 3), syncNow);
    });
    _every ??= Timer.periodic(const Duration(minutes: 5), (_) => syncNow());
    _refreshCounts();
  }

  @override
  void dispose() {
    _changes?.cancel();
    _debounce?.cancel();
    _every?.cancel();
    super.dispose();
  }

  Future<void> _refreshCounts() async {
    final p = await _pendingRows();
    final d = await _db.select(_db.syncConflicts).get();
    if (p.length != pending || d.length != decisions) {
      pending = p.length;
      decisions = d.length;
      notifyListeners();
    }
  }

  String get _accountId => account.state!.accountId;
  List<int> get _aad => utf8.encode(_accountId);

  Future<List<ChangeLogData>> _pendingRows() async {
    final device = (await library.hlc()).device;
    return (_db.select(_db.changeLog)
          ..where((r) => r.pushed.equals(false) & r.hlc.isNotNull() & r.device.equals(device) & r.bookId.equals('*').not())
          ..orderBy([(r) => OrderingTerm.asc(r.seq)]))
        .get();
  }

  /// Changes waiting to be sent, in words, for Settings.
  Future<List<(String book, String what)>> pendingList() async {
    final rows = await _pendingRows();
    final out = <(String, String)>[];
    for (final r in rows) {
      final title = (await library.getBook(r.bookId))?.title ?? _snapshotTitle(r.value) ?? 'A book';
      final what = switch (r.field) { 'created' => 'Added', 'deleted' => 'Deleted', _ => _fieldLabels[r.field] ?? r.field };
      out.add((title, what));
    }
    return out;
  }

  static String? _snapshotTitle(String? json) {
    if (json == null) return null;
    final v = jsonDecode(json);
    return v is Map ? v['title'] as String? : null;
  }

  Future<bool>? _running;

  /// One full sync. If one is already running, waits for it and then syncs once more.
  Future<bool> syncNow() async {
    if (!ready) return false;
    while (_running != null) {
      await _running;
    }
    final run = _syncOnce();
    _running = run;
    try {
      return await run;
    } finally {
      if (identical(_running, run)) _running = null;
    }
  }

  Future<bool> _syncOnce() async {
    syncing = true;
    notifyListeners();
    try {
      await _firstUpload();
      await _pull();
      await _push();
      lastSyncAt = _now();
      problem = null;
      failingSince = null;
      return true;
    } on AccountProblem catch (e) {
      problem = e.message;
      failingSince ??= _now();
      return false;
    } catch (e, st) {
      lastError = '$e | $st';
      problem = 'Sync didn\'t finish. It will try again.';
      failingSince ??= _now();
      return false;
    } finally {
      syncing = false;
      await _refreshCounts();
      notifyListeners();
    }
  }

  /// The first sync for an account sends the whole library as it is.
  Future<void> _firstUpload() async {
    final key = 'uploaded:$_accountId';
    if (await library.getMeta(key) != null) return;
    await _db.customStatement('UPDATE change_log SET pushed = 1 WHERE pushed = 0');
    for (final b in await library.allBooks()) {
      await library.logSnapshot(b.id);
      if (b.hasOwnCover) await library.logPhoto(b.id);
    }
    await library.setMeta(key, _now().toIso8601String());
  }

  // ---------- Pull and merge ----------

  Future<void> _pull() async {
    final cursorKey = 'cursor:$_accountId';
    var after = int.tryParse(await library.getMeta(cursorKey) ?? '') ?? 0;
    final me = (await library.hlc()).device;
    while (true) {
      final j = await account.authed('GET', '/v1/events?after=$after&limit=500');
      final events = (j['events'] as List? ?? const []).cast<Map>();
      for (final e in events) {
        if (e['device'] != me) {
          final plain = await open(account.libraryKey!, base64Decode(e['data'] as String), aad: _aad);
          await _merge((jsonDecode(utf8.decode(plain)) as Map).cast<String, Object?>());
        }
        after = e['seq'] as int;
        await library.setMeta(cursorKey, '$after');
      }
      if (j['more'] != true) break;
    }
  }

  Future<ChangeLogData?> _pendingFor(String bookId, String field) async => (await (_db.select(_db.changeLog)
            ..where((r) => r.bookId.equals(bookId) & r.field.equals(field) & r.pushed.equals(false) & r.hlc.isNotNull())
            ..orderBy([(r) => OrderingTerm.desc(r.seq)])
            ..limit(1))
          .get())
      .firstOrNull;

  Future<bool> _anyPendingFor(String bookId) async =>
      (await (_db.select(_db.changeLog)..where((r) => r.bookId.equals(bookId) & r.pushed.equals(false) & r.hlc.isNotNull())).get())
          .isNotEmpty;

  Future<void> _addConflict(String bookId, String field, String? local, String? remote, String hlc) async {
    await (_db.delete(_db.syncConflicts)..where((c) => c.bookId.equals(bookId) & c.field.equals(field))).go();
    await _db.into(_db.syncConflicts).insert(SyncConflictsCompanion.insert(
          bookId: bookId,
          field: field,
          localValue: Value(local),
          remoteValue: Value(remote),
          remoteHlc: hlc,
        ));
  }

  Future<void> _merge(Map<String, Object?> e) async {
    final bookId = e['b']! as String;
    final field = e['f']! as String;
    final hlc = e['h']! as String;
    final value = e['v'];
    (await library.hlc()).observe(hlc);
    final local = await library.getBook(bookId);

    if (field == 'deleted') {
      if (local == null) return;
      if (await _anyPendingFor(bookId)) {
        // Deleted there, changed here since: ask.
        await _addConflict(bookId, 'deletedThere', null, null, hlc);
      } else {
        await library.deleteQuietly(bookId);
        await covers.deleteFor(bookId);
        await library.setFieldClock(bookId, 'deleted', hlc);
      }
      return;
    }

    if (local == null) {
      final deletedHere = await _pendingFor(bookId, 'deleted');
      if (deletedHere != null) {
        // Changed there, deleted here before it was sent: ask.
        await _addConflict(bookId, 'deletedHere', deletedHere.value, jsonEncode(e), hlc);
        return;
      }
      if (field == 'created') {
        final wholeBook = await library.fieldClock(bookId, '*');
        if (wholeBook != null && wholeBook.compareTo(hlc) > 0) return; // Deleted after this was made.
        await library.insertSnapshot(bookFromJson((value! as Map).cast<String, Object?>()));
        await library.setFieldClock(bookId, '*', hlc);
      }
      return;
    }

    if (field == 'created') {
      // The same book from another device: merge it field by field.
      final snap = (value! as Map).cast<String, Object?>();
      final j = bookToJson(bookFromJson(snap));
      for (final f in _snapshotFields) {
        await _mergeField(bookId, f, j[f], hlc);
      }
      return;
    }
    await _mergeField(bookId, field, value, hlc);
  }

  Future<void> _mergeField(String bookId, String field, Object? value, String hlc) async {
    final mine = await _pendingFor(bookId, field);
    final theirs = jsonEncode(value);
    if (mine != null) {
      if (mine.value == theirs || (mine.value == null && value == null)) {
        await library.setFieldClock(bookId, field, hlc);
      } else if (field != 'photo') {
        await _addConflict(bookId, field, mine.value, theirs, hlc);
      }
      return;
    }
    final fieldClock = await library.fieldClock(bookId, field);
    final bookClock = await library.fieldClock(bookId, '*');
    final current = [fieldClock, bookClock].whereType<String>().fold<String?>(null, (a, b) => a == null || b.compareTo(a) > 0 ? b : a);
    if (current != null && current.compareTo(hlc) >= 0) return; // Ours is newer.
    await library.applyField(bookId, field, value);
    await library.setFieldClock(bookId, field, hlc);
    if (field == 'photo') await _receivePhoto(bookId, value as String?);
  }

  Future<void> _receivePhoto(String bookId, String? photoId) async {
    if (photoId == null) {
      await covers.removeOwnPhoto(bookId);
      return;
    }
    try {
      final j = await account.authed('GET', '/v1/blobs/$photoId');
      await covers.saveOwnPhoto(bookId, await open(account.libraryKey!, base64Decode(j['data']! as String), aad: _aad));
    } on AccountProblem {
      // Not uploaded yet: the downloaded cover shows until it is.
    }
  }

  // ---------- Push ----------

  Future<void> _push() async {
    final blocked = await _db.select(_db.syncConflicts).get();
    bool isBlocked(ChangeLogData r) => blocked.any((c) =>
        c.bookId == r.bookId &&
        (c.field == r.field || c.field == 'deletedThere' || (c.field == 'deletedHere' && r.field == 'deleted')));
    final rows = (await _pendingRows()).where((r) => !isBlocked(r)).toList();
    final device = (await library.hlc()).device;
    for (var i = 0; i < rows.length; i += 200) {
      final batch = rows.sublist(i, i + 200 > rows.length ? rows.length : i + 200);
      for (final r in batch.where((r) => r.field == 'photo' && r.value != null && r.value != 'null')) {
        final bytes = await covers.ownPhotoBytes(r.bookId);
        if (bytes == null) continue;
        final photoId = jsonDecode(r.value!) as String;
        await account.authed('PUT', '/v1/blobs/$photoId', body: {'data': base64Encode(await seal(account.libraryKey!, bytes, aad: _aad))});
      }
      final events = <String>[];
      for (final r in batch) {
        final e = {'i': r.seq, 'b': r.bookId, 'f': r.field, 'v': r.value == null ? null : jsonDecode(r.value!), 'h': r.hlc, 'd': device};
        events.add(base64Encode(await seal(account.libraryKey!, utf8.encode(jsonEncode(e)), aad: _aad)));
      }
      await account.authed('POST', '/v1/events', body: {'device': device, 'events': events});
      await (_db.update(_db.changeLog)..where((r) => r.seq.isIn(batch.map((b) => b.seq)))).write(const ChangeLogCompanion(pushed: Value(true)));
    }
  }

  // ---------- Her decisions ----------

  Future<List<SyncDecision>> decisionsList() async {
    final out = <SyncDecision>[];
    for (final c in await _db.select(_db.syncConflicts).get()) {
      final book = await library.getBook(c.bookId);
      final title = book?.title ?? _snapshotTitle(c.localValue) ?? 'A book';
      out.add(switch (c.field) {
        'deletedThere' => SyncDecision(id: c.id, kind: c.field, bookTitle: title, what: 'Deleted on another device, but changed here'),
        'deletedHere' => SyncDecision(id: c.id, kind: c.field, bookTitle: title, what: 'Deleted here, but changed on another device'),
        _ => SyncDecision(
            id: c.id,
            kind: 'field',
            bookTitle: title,
            what: _fieldLabels[c.field] ?? c.field,
            here: describe(c.field, c.localValue),
            there: describe(c.field, c.remoteValue),
          ),
      });
    }
    return out;
  }

  /// A value in words, for the decision screen.
  static String describe(String field, String? json) {
    final v = json == null ? null : jsonDecode(json);
    if (v == null) return 'Empty';
    return switch (field) {
      'rating' => '${'★' * (v as int)}${'☆' * (5 - v)}',
      'status' => ReadingStatus.parse(v as String)?.longLabel ?? v,
      'format' => OwnershipFormat.parse(v as String).label,
      'purchasedOn' || 'finishedOn' => (v as String).substring(0, 10),
      'authors' || 'genres' => (v as List).join(', '),
      _ => '$v',
    };
  }

  /// [keepHere]: keep this device's version; otherwise the other device's.
  Future<void> decide(int id, {required bool keepHere}) async {
    final c = await (_db.select(_db.syncConflicts)..where((x) => x.id.equals(id))).getSingleOrNull();
    if (c == null) return;
    Future<void> dropPending(String? field) => (_db.update(_db.changeLog)
          ..where((r) => r.bookId.equals(c.bookId) & r.pushed.equals(false) & (field == null ? const Constant(true) : r.field.equals(field))))
        .write(const ChangeLogCompanion(pushed: Value(true)));

    switch (c.field) {
      case 'deletedThere':
        if (keepHere) {
          await library.logSnapshot(c.bookId); // Others bring it back.
        } else {
          await dropPending(null);
          await library.deleteQuietly(c.bookId);
          await covers.deleteFor(c.bookId);
          await library.setFieldClock(c.bookId, 'deleted', c.remoteHlc);
        }
      case 'deletedHere':
        if (keepHere) {
          // Keep it deleted: the deletion is sent as it is.
        } else {
          await dropPending('deleted');
          final snap = c.localValue == null ? null : (jsonDecode(c.localValue!) as Map?)?.cast<String, Object?>();
          if (snap != null) await library.insertSnapshot(bookFromJson(snap));
          final remote = (jsonDecode(c.remoteValue!) as Map).cast<String, Object?>();
          if (remote['f'] == 'created') {
            await library.insertSnapshot(bookFromJson((remote['v']! as Map).cast<String, Object?>()));
          } else if (snap != null) {
            await library.applyField(c.bookId, remote['f']! as String, remote['v']);
          }
          await library.logSnapshot(c.bookId);
        }
      default:
        if (keepHere) {
          await dropPending(c.field);
          await library.applyField(c.bookId, c.field, c.localValue == null ? null : jsonDecode(c.localValue!));
          await _relog(c.bookId, c.field, c.localValue);
        } else {
          await dropPending(c.field);
          final v = c.remoteValue == null ? null : jsonDecode(c.remoteValue!);
          await library.applyField(c.bookId, c.field, v);
          await library.setFieldClock(c.bookId, c.field, c.remoteHlc);
        }
    }
    await (_db.delete(_db.syncConflicts)..where((x) => x.id.equals(id))).go();
    await _refreshCounts();
    if (ready) unawaited(syncNow());
  }

  /// Send a value again with a fresh clock, so it wins everywhere.
  Future<void> _relog(String bookId, String field, String? json) async {
    final clock = await library.hlc();
    final stamp = clock.next();
    await _db.into(_db.changeLog).insert(ChangeLogCompanion.insert(
          bookId: bookId,
          field: field,
          value: Value(json),
          at: _now(),
          hlc: Value(stamp),
          device: Value(clock.device),
        ));
    await library.setFieldClock(bookId, field, stamp);
  }
}
