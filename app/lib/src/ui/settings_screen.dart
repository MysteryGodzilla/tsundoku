import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_scope.dart';
import '../settings/appearance.dart';
import '../theme/palette.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int? _coverBytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshSize();
  }

  Future<void> _refreshSize() async {
    final b = await AppScope.of(context).covers.downloadedBytes();
    if (mounted) setState(() => _coverBytes = b);
  }

  Future<void> _clearCovers() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear saved covers?'),
        content: const Text('Your books stay. Covers download again when you look at them online. Your own cover photos are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AppScope.of(context).covers.clearDownloaded();
    await _refreshSize();
  }

  static String _size(int? b) {
    if (b == null) return '…';
    if (b < 1024 * 1024) return '${(b / 1024).ceil()} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final appearance = services.appearance;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget heading(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
          child: Text(s.toUpperCase(), style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1, fontWeight: FontWeight.w600)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: appearance,
        builder: (context, _) {
          final brightness = Theme.of(context).brightness;
          final effectiveDark = appearance.mode == AppearanceMode.dark ||
              (appearance.mode == AppearanceMode.system && brightness == Brightness.dark);
          return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
            heading('Appearance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Accent colour', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  Row(children: [
                    for (final a in Accent.values)
                      Expanded(child: _Swatch(accent: a, selected: a == appearance.accent, onTap: () => appearance.setAccent(a))),
                  ]),
                  const Divider(height: 32),
                  Text('Mode', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                        ButtonSegment(value: true, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                      ],
                      selected: {effectiveDark},
                      onSelectionChanged: (s) => appearance.setMode(s.first ? AppearanceMode.dark : AppearanceMode.light),
                    ),
                  ),
                  if (appearance.mode == AppearanceMode.system)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Following your phone for now.', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                ]),
              ),
            ),
            heading('Library'),
            Card(
              child: Column(children: [
                ListTile(
                  title: const Text('Saved covers'),
                  subtitle: const Text('Kept on this phone so covers show offline'),
                  trailing: Text(_size(_coverBytes)),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Clear saved covers'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _clearCovers,
                ),
              ]),
            ),
            heading('About'),
            Card(
              child: Column(children: [
                const ListTile(title: Text('Tsundoku'), subtitle: Text('Version 0.1 · free and open source')),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Book information and covers'),
                  subtitle: const Text('From Open Library, openlibrary.org'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => launchUrl(Uri.parse('https://openlibrary.org'), mode: LaunchMode.externalApplication),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.accent, required this.selected, required this.onTap});
  final Accent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colours = accentColours(accent, theme.brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: accent.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colours.accent,
                shape: BoxShape.circle,
                boxShadow: selected
                    ? [
                        BoxShadow(color: theme.colorScheme.onSurface, spreadRadius: 5),
                        BoxShadow(color: theme.colorScheme.surfaceContainerLowest, spreadRadius: 3),
                      ]
                    : null,
              ),
              child: selected ? Icon(Icons.check_rounded, color: colours.onAccent) : null,
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Text(accent.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
            ),
          ]),
        ),
      ),
    );
  }
}
