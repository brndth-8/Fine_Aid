import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';

import 'theme/admin_theme.dart';

/// Two-step verification for the admin portal: after the password, an admin
/// types the 6-digit code from an authenticator app (Google Authenticator,
/// Microsoft Authenticator, Authy, ...). The codes are Firebase Authentication's
/// own TOTP multi-factor sign-in, so the secret lives with Firebase, not here.
///
/// Enrolling is done by each admin (System Security). Whether it is REQUIRED
/// is a switch (appConfig/adminAuth) that the Firestore rules and the admin
/// Cloud Functions enforce from the sign-in token; this file is the browser's
/// side of it.

/// True when [claims] (an ID token's claims) show this sign-in went through an
/// authenticator code. Firebase puts `sign_in_second_factor` there; it can't be
/// set by a client.
bool signedInWithAuthenticator(Map<String, dynamic>? claims) {
  final firebase = claims?['firebase'];
  return firebase is Map && firebase['sign_in_second_factor'] == 'totp';
}

/// The six digits an authenticator app shows (spaces allowed).
bool isValidAuthenticatorCode(String text) =>
    RegExp(r'^\d{6}$').hasMatch(text.replaceAll(RegExp(r'\s'), ''));

/// Whether admins must sign in with an authenticator code (appConfig/adminAuth,
/// public to read). If it can't be read, "no": the server enforces it anyway.
Future<bool> adminTwoStepRequired() async {
  try {
    final snap = await FirebaseFirestore.instance
        .doc('appConfig/adminAuth')
        .get()
        .timeout(const Duration(seconds: 5));
    return snap.data()?['requireTotp'] == true;
  } catch (_) {
    return false;
  }
}

/// Live version of [adminTwoStepRequired], for the System Security switch.
Stream<bool> watchAdminTwoStepRequired() => FirebaseFirestore.instance
    .doc('appConfig/adminAuth')
    .snapshots()
    .map((snap) => snap.data()?['requireTotp'] == true);

/// Asks the server to require (or stop requiring) the code for every admin.
/// It refuses to turn it on unless this admin signed in with a code, so
/// nobody can lock themselves out. Throws on failure.
Future<void> setAdminTwoStepRequired(bool required) async {
  await FirebaseFunctions.instance
      .httpsCallable('setAdminTwoStepRequired')
      .call<Object?>({'required': required});
}

/// The authenticator-app factors enrolled for [user].
Future<List<MultiFactorInfo>> enrolledAuthenticators(User user) async {
  final all = await user.multiFactor.getEnrolledFactors();
  return all.where((f) => f.factorId == 'totp').toList();
}

/// What to tell an admin for a two-step error. [e] is usually a
/// [FirebaseAuthException] (or a [FirebaseFunctionsException]).
String describeTwoStepError(Object e) {
  var code = e is FirebaseException
      ? e.code
      : e is FirebaseFunctionsException
      ? e.code
      : '';
  var serverMessage = e is FirebaseException
      ? e.message
      : e is FirebaseFunctionsException
      ? e.message
      : null;
  if (code.isEmpty) {
    // On the web the sign-in library can hand over a raw browser error
    // instead of a FirebaseAuthException. It still carries the same
    // `auth/...` code, so read that rather than showing "JSObject".
    code = _field(e, 'code').replaceFirst('auth/', '');
    if (code.isEmpty) {
      // Property access can fail on a plain browser object; its text
      // ("FirebaseError: Firebase: Error (auth/operation-not-allowed).")
      // still names the code.
      for (final text in [_field(e, 'message'), _text(e)]) {
        final found = RegExp(r'auth/([a-z-]+)').firstMatch(text);
        if (found != null) {
          code = found.group(1)!;
          break;
        }
      }
    }
    serverMessage ??= _field(e, 'message');
  }
  switch (code) {
    case 'invalid-verification-code':
    case 'invalid-credential':
      return "That code isn't right. Check the code in your authenticator "
          'app and try again.';
    case 'code-expired':
    case 'totp-challenge-timeout':
    case 'session-expired':
      return 'That took too long. Start again.';
    case 'requires-recent-login':
      return 'For security, sign out and sign in again, then try once more.';
    case 'unverified-email':
      return "This admin account's email isn't verified yet, and Firebase "
          'only allows authenticator apps on verified emails. Send the '
          'verification email, click the link in it, then try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a few minutes and try again.';
    case 'second-factor-already-in-use':
      return 'An authenticator app is already set up on this account.';
    case 'operation-not-allowed':
    case 'unsupported-first-factor':
    case 'admin-restricted-operation':
      return "Authenticator codes aren't switched on for this project yet. "
          'The project owner has to enable them in the Firebase console '
          '(Authentication, Sign-in method, Multi-factor authentication).';
    case 'failed-precondition':
    case 'permission-denied':
      if (serverMessage != null && serverMessage.isNotEmpty) {
        return serverMessage;
      }
  }
  // Keep the code visible: it is what tells us what actually went wrong.
  final text = _text(e);
  final detail = code.isNotEmpty
      ? code
      : text.isNotEmpty
      ? (text.length > 140 ? '${text.substring(0, 140)}…' : text)
      : e.runtimeType.toString();
  return 'Something went wrong ($detail). Please try again.';
}

/// The error's own text, or '' when it only says what type it is (which
/// tells nobody anything).
String _text(Object e) {
  final text = e.toString().trim();
  return text.isEmpty || text.startsWith('Instance of ') ? '' : text;
}

/// A property of an error that isn't a typed exception ('' if it has none).
String _field(Object e, String name) {
  try {
    final dynamic d = e;
    final value = name == 'code' ? d.code : d.message;
    return value == null ? '' : value.toString();
  } catch (_) {
    return '';
  }
}

/// True when [e] means the account's email must be verified first.
bool needsVerifiedEmail(Object e) =>
    describeTwoStepError(e).contains('verification email');

/// The 6-digit code box used when signing in and when setting up.
class AuthenticatorCodeField extends StatelessWidget {
  const AuthenticatorCodeField({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.enabled = true,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        letterSpacing: 10,
        fontWeight: FontWeight.w600,
      ),
      decoration: const InputDecoration(
        hintText: '000000',
        counterText: '',
        filled: true,
        fillColor: Colors.white,
      ),
      onSubmitted: (_) => onSubmit(),
    );
  }
}

/// The dark/light squares of a QR code for [data] (true = dark).
List<List<bool>> qrMatrix(String data) {
  final image = QrImage(
    QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
  );
  return [
    for (var r = 0; r < image.moduleCount; r++)
      [for (var c = 0; c < image.moduleCount; c++) image.isDark(r, c)],
  ];
}

/// A QR code, drawn on a white square with the quiet margin scanners need.
class AuthenticatorQr extends StatelessWidget {
  const AuthenticatorQr({super.key, required this.data, this.size = 200});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'QR code to scan with your authenticator app',
      child: CustomPaint(
        size: Size.square(size),
        painter: _QrPainter(qrMatrix(data)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.matrix);

  final List<List<bool>> matrix;
  static const _quiet = 4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final modules = matrix.length + _quiet * 2;
    final cell = size.width / modules;
    final dark = Paint()..color = Colors.black;
    for (var r = 0; r < matrix.length; r++) {
      for (var c = 0; c < matrix.length; c++) {
        if (!matrix[r][c]) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (c + _quiet) * cell,
            (r + _quiet) * cell,
            cell + 0.5, // a hair over, so no seams show between squares
            cell + 0.5,
          ),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.matrix != matrix;
}

/// Walks the signed-in admin through adding an authenticator app: scan the QR
/// code (or type the key), then enter a code to prove it works. Returns true
/// once it is enrolled. Needs a recent sign-in; if Firebase says otherwise the
/// admin is told to sign in again.
Future<bool> showAuthenticatorSetup(BuildContext context) async {
  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AuthenticatorSetupDialog(),
  );
  return done == true;
}

class _AuthenticatorSetupDialog extends StatefulWidget {
  const _AuthenticatorSetupDialog();

  @override
  State<_AuthenticatorSetupDialog> createState() =>
      _AuthenticatorSetupDialogState();
}

class _AuthenticatorSetupDialogState extends State<_AuthenticatorSetupDialog> {
  final _code = TextEditingController();
  TotpSecret? _secret;
  String? _qrUrl;
  String? _error;
  bool _starting = true;
  bool _saving = false;
  bool _offerVerification = false;
  bool _verificationSent = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
      _offerVerification = false;
    });
    try {
      // Pick up an email verified since this sign-in.
      await FirebaseAuth.instance.currentUser!.reload();
      final user = FirebaseAuth.instance.currentUser!;
      final session = await user.multiFactor.getSession();
      final secret = await TotpMultiFactorGenerator.generateSecret(session);
      final url = await secret.generateQrCodeUrl(
        accountName: user.email,
        issuer: 'Fine Aid Admin',
      );
      if (!mounted) return;
      setState(() {
        _secret = secret;
        _qrUrl = url;
        _starting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeTwoStepError(e);
        _offerVerification = needsVerifiedEmail(e);
        _starting = false;
      });
    }
  }

  Future<void> _sendVerification() async {
    try {
      await FirebaseAuth.instance.currentUser!.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _verificationSent = true;
        _error =
            'Verification email sent to '
            '${FirebaseAuth.instance.currentUser!.email}. Click the link in '
            'it, then press Try again.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = describeTwoStepError(e));
    }
  }

  Future<void> _confirm() async {
    if (_saving || _secret == null) return;
    final code = _code.text.replaceAll(RegExp(r'\s'), '');
    if (!isValidAuthenticatorCode(code)) {
      setState(() => _error = 'Enter the 6-digit code from your app.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final assertion =
          await TotpMultiFactorGenerator.getAssertionForEnrollment(
            _secret!,
            code,
          );
      await FirebaseAuth.instance.currentUser!.multiFactor.enroll(
        assertion,
        displayName: 'Authenticator app',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeTwoStepError(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Set up authenticator app'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Install an authenticator app on your phone (Google '
                'Authenticator, Microsoft Authenticator or Authy).\n'
                '2. In the app, add an account and scan this code.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (_starting)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_qrUrl != null) ...[
                Center(child: AuthenticatorQr(data: _qrUrl!, size: 190)),
                const SizedBox(height: 10),
                Text(
                  "Can't scan it? Enter this key in the app instead:",
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _secret!.secretKey,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy key',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _secret!.secretKey),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Key copied.')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '3. Enter the 6-digit code the app shows now:',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                AuthenticatorCodeField(
                  controller: _code,
                  enabled: !_saving,
                  onSubmit: _confirm,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (_offerVerification && !_verificationSent)
          OutlinedButton(
            onPressed: _sendVerification,
            child: const Text('Send verification email'),
          ),
        if (_secret == null && !_starting)
          OutlinedButton(onPressed: _start, child: const Text('Try again'))
        else
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.maroon,
              foregroundColor: Colors.white,
            ),
            onPressed: _saving || _starting || _secret == null
                ? null
                : _confirm,
            child: Text(_saving ? 'Checking…' : 'Turn on'),
          ),
      ],
    );
  }
}
