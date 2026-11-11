import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/phone_otp_strings.dart';
import '../../services/api/semaphore_service.dart';

typedef SendOtpCode = Future<bool> Function(String phoneNumber);
typedef VerifyOtpCode = Future<OtpVerificationResult> Function(String code);

Future<bool> _sendWithSemaphore(String phoneNumber) =>
    SemaphoreService().sendOtp(phoneNumber: phoneNumber);

Future<OtpVerificationResult> _verifyWithSemaphore(String code) =>
    SemaphoreService().verifyOtp(code: code);

/// Sends a 6-digit code by SMS to [phoneNumber] ("+639...") and asks for it.
/// True only once the right code was entered; false when cancelled. The same
/// SMS service and code check the sign-up verification uses.
Future<bool> showPhoneOtpDialog(
  BuildContext context, {
  required String phoneNumber,
  SendOtpCode? sendCode,
  VerifyOtpCode? verifyCode,
}) async {
  final verified = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PhoneOtpDialog(
      phoneNumber: phoneNumber,
      sendCode: sendCode ?? _sendWithSemaphore,
      verifyCode: verifyCode ?? _verifyWithSemaphore,
    ),
  );
  return verified == true;
}

class _PhoneOtpDialog extends StatefulWidget {
  final String phoneNumber;
  final SendOtpCode sendCode;
  final VerifyOtpCode verifyCode;

  const _PhoneOtpDialog({
    required this.phoneNumber,
    required this.sendCode,
    required this.verifyCode,
  });

  @override
  State<_PhoneOtpDialog> createState() => _PhoneOtpDialogState();
}

class _PhoneOtpDialogState extends State<_PhoneOtpDialog> {
  final _code = TextEditingController();
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _busy = false;
  bool _codeSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _send());
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.sendCode(widget.phoneNumber);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _codeSent = ok;
      if (!ok) _error = PhoneOtpStrings.of(context).couldNotSend;
    });
    if (ok) _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.verifyCode(_code.text.trim());
    if (!mounted) return;
    final s = PhoneOtpStrings.of(context);
    if (result == OtpVerificationResult.success) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      switch (result) {
        case OtpVerificationResult.invalid:
          _error = s.incorrect;
        case OtpVerificationResult.expired:
          _error = s.expired;
          _codeSent = false;
        case OtpVerificationResult.tooManyAttempts:
          _error = s.tooMany;
          _codeSent = false;
        default:
          _error = s.failed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = PhoneOtpStrings.of(context);
    final theme = Theme.of(context);
    final canVerify = _codeSent && !_busy && _code.text.trim().length == 6;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.bodyFor(widget.phoneNumber)),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: s.codeHint,
                  counterText: '',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: (_busy || _cooldown > 0) ? null : _send,
                child: Text(
                  _cooldown > 0 ? s.resendInFor(_cooldown) : s.resend,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: canVerify ? _verify : null,
            child: _busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.verify),
          ),
        ],
      ),
    );
  }
}
