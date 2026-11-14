import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../sync/sync_service.dart';

/// Things changed on two devices that need her choice. Nothing is lost until she chooses.
class DecisionsScreen extends StatefulWidget {
  const DecisionsScreen({super.key});
  @override
  State<DecisionsScreen> createState() => _DecisionsScreenState();
}

class _DecisionsScreenState extends State<DecisionsScreen> {
  Future<List<SyncDecision>>? _load;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= AppScope.of(context).sync.decisionsList();
  }

  Future<void> _decide(SyncDecision d, {required bool keepHere}) async {
    setState(() => _busy = true);
    final sync = AppScope.of(context).sync;
    await sync.decide(d.id, keepHere: keepHere);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load = sync.decisionsList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sync questions')),
      body: FutureBuilder<List<SyncDecision>>(
        future: _load,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Nothing to decide.'));
          return ListView(padding: EdgeInsets.fromLTRB(20, 0, 20, 48 + MediaQuery.paddingOf(context).bottom), children: [
            Text('The same thing was changed on two devices. Choose which to keep; the other device will follow.',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            for (final d in list) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(d.bookTitle, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text(d.what, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    ...switch (d.kind) {
                      'deletedThere' => [
                          FilledButton(onPressed: _busy ? null : () => _decide(d, keepHere: true), child: const Text('Keep the book')),
                          const SizedBox(height: 8),
                          OutlinedButton(onPressed: _busy ? null : () => _decide(d, keepHere: false), child: const Text('Delete it')),
                        ],
                      'deletedHere' => [
                          FilledButton(onPressed: _busy ? null : () => _decide(d, keepHere: false), child: const Text('Bring it back')),
                          const SizedBox(height: 8),
                          OutlinedButton(onPressed: _busy ? null : () => _decide(d, keepHere: true), child: const Text('Keep it deleted')),
                        ],
                      _ => [
                          _Choice(label: 'On this phone', value: d.here ?? '', onTap: _busy ? null : () => _decide(d, keepHere: true)),
                          const SizedBox(height: 8),
                          _Choice(label: 'On the other device', value: d.there ?? '', onTap: _busy ? null : () => _decide(d, keepHere: false)),
                        ],
                    },
                  ]),
                ),
              ),
            ],
          ]);
        },
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: cs.outlineVariant),
        foregroundColor: cs.onSurface,
      ),
      onPressed: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Keep: $label', style: TextStyle(color: cs.tertiary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
      ]),
    );
  }
}

/// Changes on this phone not sent yet (a product rule: she can see what's waiting).
class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = AppScope.of(context).sync;
    return Scaffold(
      appBar: AppBar(title: const Text('Waiting to sync')),
      body: FutureBuilder<List<(String, String)>>(
        future: sync.pendingList(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Everything is synced.'));
          return ListView.separated(
            padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
            itemBuilder: (_, i) => ListTile(title: Text(list[i].$1), subtitle: Text(list[i].$2)),
          );
        },
      ),
    );
  }
}
