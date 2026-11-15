import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart' show base32Decode, otpauthUri;
import 'package:url_launcher/url_launcher.dart';

import '../account/account_service.dart';
import '../account/server_address.dart';
import '../app_scope.dart';
import 'recovery_screens.dart';
import 'server_warning.dart';

/// Sign in or create an account for sync. Optional: the app works fully without one.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _form = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    // The server she used last time, as she'd type it (https is assumed when left off).
    final last = AppScope.of(context).account.lastServerUrl;
    if (last != null) _server.text = last.replaceFirst(RegExp(r'^https://'), '');
  }

  Future<void> _forgotPassword() async {
    final nav = Navigator.of(context);
    final outcome = await nav.push<ResetOutcome>(MaterialPageRoute(
      builder: (_) => ResetPasswordScreen(serverUrl: _server.text.trim(), email: _email.text.trim()),
    ));
    if (!mounted) return;
    switch (outcome) {
      // Signed in: straight back to Settings, which shows it.
      case ResetOutcome.signedIn:
        nav.pop();
      // Started again: the old passkey and code are gone, so set up a new one; then Settings.
      case ResetOutcome.startedAgain:
        nav.pushReplacement(MaterialPageRoute(builder: (_) => const RecoverySetupScreen(firstTime: true, afterStartingAgain: true)));
      case null:
        break;
    }
  }

  @override
  void dispose() {
    for (final c in [_server, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final account = AppScope.of(context).account;
    final nav = Navigator.of(context);
    try {
      // Finds the server (https first, then plain http for a home server) and warns before plain http.
      final url = await account.checkServer(_server.text);
      if (isPlainHttp(url) && mounted && !await confirmPlainHttp(context, url)) return;
      if (_creating) {
        final secret = await account.signUp(serverUrl: url, email: _email.text, password: _password.text);
        nav.pushReplacement(MaterialPageRoute(builder: (_) => TotpSetupScreen(secret: secret)));
      } else {
        await account.signIn(serverUrl: url, email: _email.text, password: _password.text);
        if (account.state?.totpConfirmed == false) {
          nav.pushReplacement(MaterialPageRoute(builder: (_) => const TotpSetupScreen()));
        } else {
          nav.pop();
        }
      }
    } on AccountProblem catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sync')),
      body: Form(
        key: _form,
        child: ListView(padding: EdgeInsets.fromLTRB(20, 0, 20, 48 + MediaQuery.paddingOf(context).bottom), children: [
          Text(
            'Optional. Sync keeps your library on more than one device through a Tsundoku server. '
            'Your books are locked on this phone before they\'re sent: nobody else can read them, not even whoever runs the server. '
            'You can stop at any time; your books stay on this phone.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: false, label: Text('Sign in')), ButtonSegment(value: true, label: Text('Create account'))],
              selected: {_creating},
              onSelectionChanged: (s) => setState(() {
                _creating = s.first;
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _server,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Sync server address',
              hintText: 'books.example.com',
              helperText: 'From whoever runs it. A server at home looks like 10.0.0.20:8797.',
              helperMaxLines: 2,
            ),
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
          TextFormField(
            controller: _password,
            obscureText: !_showPassword,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: _creating ? 'At least $minPasswordLength characters. A few words together works well.' : null,
              helperMaxLines: 2,
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            validator: (v) => _creating && (v ?? '').length < minPasswordLength ? 'Use at least $minPasswordLength characters' : ((v ?? '').isEmpty ? 'Your password' : null),
          ),
          if (_creating) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: !_showPassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Password again'),
              validator: (v) => v == _password.text ? null : 'The passwords don\'t match',
            ),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: TextStyle(color: cs.error))),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(_creating ? 'Create account' : 'Sign in'),
          ),
          if (!_creating)
            TextButton(onPressed: _busy ? null : _forgotPassword, child: const Text('Forgot password?')),
          if (_creating)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Next you\'ll add Tsundoku to an authenticator app. Its codes let you reset a forgotten password.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Adds the account to her authenticator app and checks one code. Without [secret] (finishing
/// setup later) it asks the server for it.
class TotpSetupScreen extends StatefulWidget {
  const TotpSetupScreen({super.key, this.secret});
  final String? secret;

  @override
  State<TotpSetupScreen> createState() => _TotpSetupScreenState();
}

class _TotpSetupScreenState extends State<TotpSetupScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  late String? _secret = widget.secret;
  String? _loadError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_secret == null && _loadError == null) _load();
  }

  Future<void> _load() async {
    try {
      final s = await AppScope.of(context).account.totpSetupSecret();
      if (mounted) setState(() => _secret = s);
    } on AccountProblem catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _grouped => RegExp(r'.{1,4}').allMatches(_secret!).map((m) => m.group(0)).join(' ');

  Future<void> _openAuthenticator() async {
    final account = AppScope.of(context).account;
    final messenger = ScaffoldMessenger.of(context);
    final uri = otpauthUri(secretBase32: _secret!, account: account.state?.email ?? 'Tsundoku');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No authenticator app found. Install one (Google Authenticator, Microsoft Authenticator or Aegis), or type the key into it.'),
      ));
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      await AppScope.of(context).account.confirmTotp(_code.text);
      // Next: a way back into the library if the password is ever forgotten.
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const RecoverySetupScreen(firstTime: true)));
    } on AccountProblem catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasSecret = _secret != null && base32Decode(_secret!).isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Authenticator app')),
      body: ListView(padding: EdgeInsets.fromLTRB(20, 0, 20, 48 + MediaQuery.paddingOf(context).bottom), children: [
        Text(
          'If you ever forget your password, a 6-digit code from an authenticator app lets you set a new one.',
          style: tt.bodyLarge,
        ),
        const SizedBox(height: 20),
        if (hasSecret) ...[
          FilledButton.icon(onPressed: _openAuthenticator, icon: const Icon(Icons.add_moderator_outlined), label: const Text('Add to authenticator app')),
          const SizedBox(height: 16),
          Text('Or type this key into it:', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: SelectableText(_grouped, style: const TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 1))),
            IconButton(
              tooltip: 'Copy key',
              icon: const Icon(Icons.copy),
              onPressed: () => Clipboard.setData(ClipboardData(text: _secret!)),
            ),
          ]),
          const SizedBox(height: 24),
          Text('Then type the code it shows:', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(hintText: '123456', errorText: _error, counterText: ''),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _confirm, child: const Text('Check code')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Do this later')),
        ] else if (_loadError != null)
          Text(_loadError!, style: TextStyle(color: cs.error))
        else
          const Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}
