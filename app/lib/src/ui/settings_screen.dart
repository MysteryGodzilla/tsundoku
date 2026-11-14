import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../app_scope.dart';
import '../backup/backup_service.dart';
import '../backup/backup_store.dart';
import '../export/library_export.dart';
import '../settings/appearance.dart';
import '../theme/palette.dart';
import 'restore_screen.dart';
import 'widgets.dart';

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

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final books = await AppScope.of(context).library.allBooks();
      await shareLibrarySpreadsheet(books);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Couldn\'t make the spreadsheet.')));
    }
  }

  Future<void> _backupNow(BackupService b) async {
    final ok = await b.backupNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Backed up' : (b.lastError ?? 'The backup didn\'t work.'))));
  }

  Future<void> _chooseWhere(BackupService b) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Where to keep backups', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Choose a folder'),
              subtitle: const Text('Google Drive, for example. Backups there survive losing your phone.'),
              onTap: () => Navigator.pop(c, 'folder'),
            ),
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('On this phone only'),
              subtitle: const Text('Lost if the phone is lost or Tsundoku is uninstalled.'),
              onTap: () => Navigator.pop(c, 'phone'),
            ),
          ]),
        ),
      ),
    );
    if (choice == 'folder') {
      if (await b.chooseFolder()) await _backupNow(b);
    } else if (choice == 'phone') {
      await b.useThisPhone();
    }
  }

  Widget _backupsCard(BuildContext context, BackupService b) {
    final cs = Theme.of(context).colorScheme;
    final last = b.lastBackupAt;
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          title: const Text('Where'),
          subtitle: Text(b.folderUri == null
              ? 'On this phone only. Choose a folder (like Google Drive) so a backup survives losing your phone.'
              : b.folderName ?? 'The folder you chose'),
          trailing: Text(b.folderUri == null ? 'Choose' : 'Change', style: TextStyle(color: cs.tertiary, fontWeight: FontWeight.w600)),
          onTap: () => _chooseWhere(b),
        ),
        const Divider(indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('How often', style: Theme.of(context).textTheme.bodyLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 1, label: Text('Daily')), ButtonSegment(value: 7, label: Text('Weekly'))],
              selected: {b.frequencyDays},
              onSelectionChanged: (s) => b.setFrequencyDays(s.first),
            ),
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          title: const Text('Keep backups for'),
          trailing: DropdownButton<int>(
            value: b.retentionDays,
            underline: const SizedBox(),
            items: [for (final d in BackupService.retentionChoices) DropdownMenuItem(value: d, child: Text('$d days'))],
            onChanged: (d) => d == null ? null : b.setRetentionDays(d),
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          title: const Text('Last backup'),
          subtitle: Text(
            b.lastError ?? (last == null ? 'Not yet' : '${formatDate(last)}, ${two(last.hour)}:${two(last.minute)}'),
            style: b.lastError == null ? null : TextStyle(color: cs.error),
          ),
          trailing: TextButton(onPressed: () => _backupNow(b), child: const Text('Back up now')),
        ),
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          title: const Text('Restore from a backup'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RestoreScreen())),
        ),
      ]),
    );
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
        listenable: Listenable.merge([appearance, services.backups]),
        builder: (context, _) {
          final brightness = Theme.of(context).brightness;
          final effectiveDark = appearance.mode == AppearanceMode.dark ||
              (appearance.mode == AppearanceMode.system && brightness == Brightness.dark);
          return ListView(padding: EdgeInsets.fromLTRB(20, 0, 20, 48 + MediaQuery.paddingOf(context).bottom), children: [
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
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Export to spreadsheet'),
                  subtitle: const Text('Every book and detail, as an Excel file'),
                  trailing: const Icon(Icons.ios_share),
                  onTap: _export,
                ),
              ]),
            ),
            heading('Backups'),
            _backupsCard(context, services.backups),
            heading('About'),
            Card(
              child: Column(children: [
                const ListTile(title: Text('Tsundoku'), subtitle: Text('Version $appVersion · free and open source')),
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
