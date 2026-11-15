/// Step 3c screens: ways back into the library, a forgotten password, a new password or email.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../account/account_service.dart';
import '../account/passkey_recovery.dart';
import '../account/server_address.dart';
import '../app_scope.dart';
import 'server_warning.dart';

EdgeInsets _pagePadding(BuildContext context) => EdgeInsets.fromLTRB(20, 0, 20, 48 + MediaQuery.paddingOf(context).bottom);

/// The 6-digit code from her authenticator app.
class AuthCodeField extends StatelessWidget {
  const AuthCodeField({super.key, required this.controller, this.onSubmitted, this.label = 'Code from your authenticator app'});
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final String label;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        maxLength: 6,
        decoration: InputDecoration(labelText: label, hintText: '123456', counterText: ''),
        validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim()) ? null : 'The 6 digits it shows now',
        onFieldSubmitted: onSubmitted,
      );
}

/// A new password, typed twice, with a show/hide button.
class NewPasswordFields extends StatefulWidget {
  const NewPasswordFields({super.key, required this.password, required this.again});
  final TextEditingController password;
  final TextEditingController again;
  @override
  State<NewPasswordFields> createState() => _NewPasswordFieldsState();
}

class _NewPasswordFieldsState extends State<NewPasswordFields> {
  bool _show = false;

  @override
  Widget build(BuildContext context) => Column(children: [
        TextFormField(
          controller: widget.password,
          obscureText: !_show,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'New password',
            helperText: 'At least $minPasswordLength characters. A few words together works well.',
            helperMaxLines: 2,
            suffixIcon: IconButton(
              tooltip: _show ? 'Hide password' : 'Show password',
              icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
          validator: (v) => (v ?? '').length < minPasswordLength ? 'Use at least $minPasswordLength characters' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: widget.again,
          obscureText: !_show,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'New password again'),
          validator: (v) => v == widget.password.text ? null : 'The passwords don\'t match',
        ),
      ]);
}

Widget _errorText(BuildContext context, String? message) => message == null
    ? const SizedBox.shrink()
    : Padding(padding: const EdgeInsets.only(top: 16), child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)));

Widget _busyLabel(bool busy, String label) =>
    busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Text(label);

// ---------------------------------------------------------------------------------------------

/// Ways to open the synced library on a new phone after a forgotten password: a passkey in her
/// Google account (fingerprint), or a recovery code she keeps.
class RecoverySetupScreen extends StatefulWidget {
  const RecoverySetupScreen({super.key, this.firstTime = false});

  /// Straight after the authenticator setup: offers "Do this later".
  final bool firstTime;
  @override
  State<RecoverySetupScreen> createState() => _RecoverySetupScreenState();
}

class _RecoverySetupScreenState extends State<RecoverySetupScreen> {
  RecoveryStatus? _status;
  String? _loadError;
  String? _error;
  String? _newCode;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_status == null && _loadError == null) _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final s = await AppScope.of(context).account.recoveryStatus();
      if (mounted) setState(() => _status = s);
    } on AccountProblem catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  Future<void> _savePasskey() async {
    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final s = services.account.state!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final details = await services.passkeys.create(accountId: s.accountId, email: s.email);
      if (details == null) {
        setState(() => _error = 'This phone can\'t use a passkey for this. Make a recovery code instead.');
        return;
      }
      final status = await services.account.savePasskeyRecovery(credentialId: details.credentialId, prfSalt: details.prfSalt, secret: details.secret);
      if (!mounted) return;
      setState(() => _status = status);
      messenger.showSnackBar(const SnackBar(content: Text('Passkey saved.'), persist: false));
    } on PasskeyCancelled {
      // She closed the sheet.
    } on AccountProblem catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _makeCode() async {
    final account = AppScope.of(context).account;
    if (_status?.code == true) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Make a new recovery code?'),
          content: const Text('The old code will stop working.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Make a new code')),
          ],
        ),
      );
      if (go != true) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await account.makeRecoveryCode();
      if (!mounted) return;
      setState(() {
        _newCode = code;
        _status = RecoveryStatus(passkey: _status?.passkey ?? false, code: true);
      });
    } on AccountProblem catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('If you forget your password')),
      body: ListView(padding: _pagePadding(context), children: [
        Text(
          'Your authenticator app lets you set a new password. To open your synced library on a new phone after that, '
          'you also need one of these. Nobody else can open it for you, not even whoever runs the server.',
          style: tt.bodyLarge,
        ),
        const SizedBox(height: 20),
        if (s == null && _loadError == null) const Center(child: CircularProgressIndicator()),
        if (_loadError != null) ...[
          Text(_loadError!, style: TextStyle(color: cs.error)),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ],
        if (s != null) ...[
          _RecoveryCard(
            icon: Icons.fingerprint,
            title: 'Passkey',
            done: s.passkey,
            text: s.passkey
                ? 'Saved in your Google account. A new phone opens your library with your fingerprint.'
                : 'Saved in your Google account, so a new phone can open your library with your fingerprint. Nothing to write down.',
            action: s.passkey ? 'Save again' : 'Save a passkey',
            onPressed: _busy ? null : _savePasskey,
          ),
          const SizedBox(height: 12),
          _RecoveryCard(
            icon: Icons.password,
            title: 'Recovery code',
            done: s.code,
            text: s.code
                ? 'Made. Keep it somewhere safe. A new code replaces the old one.'
                : 'A code to write down or keep in a password manager, for when a passkey isn\'t possible.',
            action: s.code ? 'Make a new code' : 'Make a recovery code',
            onPressed: _busy ? null : _makeCode,
            secondary: s.passkey,
          ),
          if (_newCode != null) ...[
            const SizedBox(height: 16),
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Your recovery code', style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SelectableText(_newCode!,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 18, letterSpacing: 1, color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Write it down or save it in a password manager now. It won\'t be shown again.',
                      style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _newCode!));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied.'), persist: false));
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                  ),
                ]),
              ),
            ),
          ],
          _errorText(context, _error),
          const SizedBox(height: 24),
          if (widget.firstTime)
            s.any
                ? FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))
                : TextButton(onPressed: () => Navigator.pop(context), child: const Text('Do this later')),
        ],
      ]),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({required this.icon, required this.title, required this.done, required this.text, required this.action, required this.onPressed, this.secondary = false});
  final IconData icon;
  final String title;
  final bool done;
  final String text;
  final String action;
  final VoidCallback? onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: cs.tertiary),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
            if (done) Icon(Icons.check_circle_outline, color: cs.tertiary),
          ]),
          const SizedBox(height: 8),
          Text(text, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          done || secondary
              ? OutlinedButton(onPressed: onPressed, child: Text(action))
              : FilledButton(onPressed: onPressed, child: Text(action)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------

enum _ResetStep { who, unlock, code, none, password }

/// Forgotten password, when no device is signed in: email and authenticator code, then the
/// passkey or recovery code to open the library, then a new password.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.serverUrl = '', this.email = ''});
  final String serverUrl;
  final String email;
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _server = TextEditingController(text: widget.serverUrl);
  late final _email = TextEditingController(text: widget.email);
  final _totp = TextEditingController();
  final _recoveryCode = TextEditingController();
  final _password = TextEditingController();
  final _again = TextEditingController();
  _ResetStep _step = _ResetStep.who;
  PasswordReset? _reset;
  Uint8List? _libraryKey;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_server, _email, _totp, _recoveryCode, _password, _again]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(_ResetStep step) => setState(() {
        _step = step;
        _error = null;
      });

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
    } on PasskeyCancelled {
      // She closed the sheet.
    } on AccountProblem catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    if (!_form.currentState!.validate()) return;
    final account = AppScope.of(context).account;
    await _run(() async {
      final url = await account.checkServer(_server.text);
      if (isPlainHttp(url) && mounted && !await confirmPlainHttp(context, url)) return;
      final r = await account.startReset(serverUrl: url, email: _email.text, code: _totp.text);
      _reset = r;
      _go(r.hasPasskey || r.hasCode ? _ResetStep.unlock : _ResetStep.none);
    });
  }

  Future<void> _usePasskey() async {
    final services = AppScope.of(context);
    final r = _reset!;
    await _run(() async {
      final secret = await services.passkeys.secret(credentialId: r.passkeyId!, prfSalt: r.passkeySalt!);
      _libraryKey = await services.account.unlockWithPasskey(r, secret);
      _go(_ResetStep.password);
    });
  }

  Future<void> _useCode() async {
    final account = AppScope.of(context).account;
    await _run(() async {
      _libraryKey = await account.unlockWithCode(_reset!, _recoveryCode.text);
      _go(_ResetStep.password);
    });
  }

  Future<void> _finish() async {
    if (!_form.currentState!.validate()) return;
    final account = AppScope.of(context).account;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final fresh = _libraryKey == null;
    await _run(() async {
      try {
        await account.finishReset(_reset!, newPassword: _password.text, libraryKey: _libraryKey);
      } on AccountProblem catch (e) {
        if (e.message.contains('too long')) {
          _go(_ResetStep.who);
          _totp.clear();
        }
        rethrow;
      }
      messenger.showSnackBar(SnackBar(
        content: Text(fresh ? 'New password set. Your synced library starts again from this phone.' : 'New password set. You\'re signed in.'),
        persist: false,
      ));
      nav.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = _reset;
    final muted = tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant);
    final children = switch (_step) {
      _ResetStep.who => [
          Text('Set a new password with a code from your authenticator app.', style: tt.bodyLarge),
          const SizedBox(height: 8),
          Text('If Tsundoku is still signed in on another phone or tablet, it\'s easier there: Settings, then Change password.', style: muted),
          const SizedBox(height: 20),
          TextFormField(
            controller: _server,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Sync server address'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'The address of your Tsundoku server' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim()) ? null : 'That email doesn\'t look right',
          ),
          const SizedBox(height: 14),
          AuthCodeField(controller: _totp, onSubmitted: (_) => _start()),
          _errorText(context, _error),
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _start, child: _busyLabel(_busy, 'Next')),
        ],
      _ResetStep.unlock => [
          Text('Now open your synced library.', style: tt.bodyLarge),
          const SizedBox(height: 20),
          if (r!.hasPasskey) ...[
            FilledButton.icon(onPressed: _busy ? null : _usePasskey, icon: const Icon(Icons.fingerprint), label: const Text('Use my passkey')),
            const SizedBox(height: 12),
          ],
          if (r.hasCode) ...[
            (r.hasPasskey ? OutlinedButton.new : FilledButton.new)(
              onPressed: _busy ? null : () => _go(_ResetStep.code),
              child: const Text('Use my recovery code'),
            ),
            const SizedBox(height: 12),
          ],
          TextButton(onPressed: _busy ? null : () => _go(_ResetStep.none), child: const Text('I can\'t do either')),
          _errorText(context, _error),
        ],
      _ResetStep.code => [
          Text('Type your recovery code.', style: tt.bodyLarge),
          const SizedBox(height: 20),
          TextFormField(
            controller: _recoveryCode,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1),
            decoration: const InputDecoration(labelText: 'Recovery code', hintText: 'ABCD-EFGH-…'),
            onFieldSubmitted: (_) => _useCode(),
          ),
          _errorText(context, _error),
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _useCode, child: _busyLabel(_busy, 'Open my library')),
          TextButton(onPressed: _busy ? null : () => _go(_ResetStep.unlock), child: const Text('Back')),
        ],
      _ResetStep.none => [
          Text('Without your passkey or recovery code, nobody can open your synced library, not even whoever runs the server. '
              'That\'s what keeps it private.', style: tt.bodyLarge),
          const SizedBox(height: 12),
          Text('You can set a new password and start the synced copy again from the books on this phone. '
              'Anything that was only on the server is lost.', style: muted),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
            onPressed: () {
              _libraryKey = null;
              _go(_ResetStep.password);
            },
            child: const Text('Start again from this phone'),
          ),
          if (r != null && (r.hasPasskey || r.hasCode)) TextButton(onPressed: () => _go(_ResetStep.unlock), child: const Text('Back')),
        ],
      _ResetStep.password => [
          Text(_libraryKey == null ? 'Choose a new password. The synced copy starts again from this phone.' : 'Your library is open. Choose a new password.',
              style: tt.bodyLarge),
          const SizedBox(height: 20),
          NewPasswordFields(password: _password, again: _again),
          _errorText(context, _error),
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _finish, child: _busyLabel(_busy, 'Set new password')),
          const SizedBox(height: 12),
          Text('Other phones and tablets will ask you to sign in again with the new password.', style: muted),
        ],
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Forgotten password')),
      body: Form(key: _form, child: ListView(padding: _pagePadding(context), children: children)),
    );
  }
}

// ---------------------------------------------------------------------------------------------

/// Signed in: a new password with an authenticator code (works even if the old one is forgotten).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _totp = TextEditingController();
  final _password = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_totp, _password, _again]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final account = AppScope.of(context).account;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await account.changePassword(code: _totp.text, newPassword: _password.text);
      messenger.showSnackBar(const SnackBar(content: Text('Password changed. Other devices will ask you to sign in again.'), persist: false));
      nav.pop();
    } on AccountProblem catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Form(
        key: _form,
        child: ListView(padding: _pagePadding(context), children: [
          Text('You don\'t need the old password, just a code from your authenticator app.', style: tt.bodyLarge),
          const SizedBox(height: 20),
          NewPasswordFields(password: _password, again: _again),
          const SizedBox(height: 14),
          AuthCodeField(controller: _totp, onSubmitted: (_) => _save()),
          _errorText(context, _error),
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _save, child: _busyLabel(_busy, 'Change password')),
        ]),
      ),
    );
  }
}

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});
  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _totp = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _totp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final account = AppScope.of(context).account;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await account.changeEmail(email: _email.text, code: _totp.text);
      messenger.showSnackBar(const SnackBar(content: Text('Email changed. Use it next time you sign in.'), persist: false));
      nav.pop();
    } on AccountProblem catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final current = AppScope.of(context).account.state?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Change email')),
      body: Form(
        key: _form,
        child: ListView(padding: _pagePadding(context), children: [
          Text('Now: $current', style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'New email'),
            validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim()) ? null : 'That email doesn\'t look right',
          ),
          const SizedBox(height: 14),
          AuthCodeField(controller: _totp, onSubmitted: (_) => _save()),
          _errorText(context, _error),
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _save, child: _busyLabel(_busy, 'Change email')),
        ]),
      ),
    );
  }
}
