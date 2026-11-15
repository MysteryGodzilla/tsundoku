import 'package:material_ui/material_ui.dart';

/// Before using a plain http server (often a home server): what the risk is, that https is
/// recommended, and her agreement to go ahead.
Future<bool> confirmPlainHttp(BuildContext context, String url) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => _PlainHttpDialog(url: url));
  return ok == true;
}

class _PlainHttpDialog extends StatefulWidget {
  const _PlainHttpDialog({required this.url});
  final String url;
  @override
  State<_PlainHttpDialog> createState() => _PlainHttpDialogState();
}

class _PlainHttpDialogState extends State<_PlainHttpDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return AlertDialog(
      icon: Icon(Icons.lock_open_outlined, color: cs.error),
      title: const Text('This server isn\'t secure'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.url.replaceFirst(RegExp(r'^http://'), '')} uses plain http, not https. We recommend https: '
              'ask whoever runs the server to set it up (the install guide shows how).'),
          const SizedBox(height: 12),
          const Text('Your books, notes and photos are still locked before they leave this phone, so nobody can read them on the way. '
              'But someone else on the same network could catch your sign-in and use it to change or delete the synced copy '
              'on the server. The books on this phone would stay safe.'),
          const SizedBox(height: 12),
          Text('Only carry on if you trust the network, like your own home Wi-Fi.', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v ?? false),
            title: const Text('I understand the risks'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _agreed ? () => Navigator.pop(context, true) : null, child: const Text('Carry on')),
      ],
    );
  }
}
