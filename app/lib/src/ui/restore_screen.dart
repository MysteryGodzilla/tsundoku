import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../backup/backup_store.dart';
import 'widgets.dart';

/// Pick a backup to restore. Lists backups in the chosen folder and on this phone, newest first.
class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key});
  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  Future<List<(BackupStore, List<BackupEntry>)>>? _load;
  bool _working = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= _list();
  }

  Future<List<(BackupStore, List<BackupEntry>)>> _list() async {
    final b = AppScope.of(context).backups;
    final stores = <BackupStore>[b.store, if (b.store != b.local && b.folderUri != null) b.local];
    final out = <(BackupStore, List<BackupEntry>)>[];
    for (final s in stores) {
      try {
        out.add((s, await s.list()));
      } catch (_) {
        out.add((s, const []));
      }
    }
    return out;
  }

  String _when(DateTime t) => '${formatDate(t)}, ${two(t.hour)}:${two(t.minute)}';

  Future<void> _restore(BackupStore from, BackupEntry e) async {
    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _working = true);
    try {
      final contents = await services.backups.peek(e, from: from);
      final current = await services.library.count();
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Restore this backup?'),
          content: Text(
            'The backup from ${_when(e.createdAt)} has ${contents.books.length} book${contents.books.length == 1 ? '' : 's'}. '
            'It will replace the $current book${current == 1 ? '' : 's'} on this phone.'
            '${current > 0 ? '\n\nA copy of your library as it is now is kept on this phone first, in case you change your mind.' : ''}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restore')),
          ],
        ),
      );
      if (ok != true) return;
      await services.backups.restore(contents);
      messenger.showSnackBar(SnackBar(content: Text('Restored ${contents.books.length} book${contents.books.length == 1 ? '' : 's'}')));
      nav.popUntil((r) => r.isFirst);
    } on FormatException catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(err.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Couldn\'t read that backup.')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Restore')),
      body: Stack(children: [
        FutureBuilder<List<(BackupStore, List<BackupEntry>)>>(
          future: _load,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final groups = snap.data!;
            final any = groups.any((g) => g.$2.isNotEmpty);
            return ListView(padding: EdgeInsets.fromLTRB(20, 0, 20, 48 + MediaQuery.paddingOf(context).bottom), children: [
              Text(
                'Restoring replaces the books on this phone with the ones in the backup.',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (!any)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Text(
                    'No backups found. On a new phone, first choose the folder your backups are in (Settings, Backups, Where).',
                    style: tt.bodyLarge,
                  ),
                ),
              for (final (store, entries) in groups)
                if (entries.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
                    child: Text(
                      (store.description == 'this phone' ? 'On this phone' : 'In ${store.description}').toUpperCase(),
                      style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Card(
                    child: Column(children: [
                      for (final (i, e) in entries.indexed) ...[
                        if (i > 0) const Divider(indent: 16, endIndent: 16),
                        ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(_when(e.createdAt)),
                          subtitle: Text('${(e.size / 1024).ceil()} KB'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _working ? null : () => _restore(store, e),
                        ),
                      ],
                    ]),
                  ),
                ],
            ]);
          },
        ),
        if (_working) const LinearProgressIndicator(minHeight: 2),
      ]),
    );
  }
}
