import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../i18n/screen_text_strings.dart';
import '../../../i18n/offline_strings.dart';
import '../../../services/connectivity_service.dart';

/// What a user writes in the feedback form: up to 100 characters (no minimum).
/// This applies to this form only; the admin's reply has its own, separate rule.
const int userFeedbackMaxLength = 100;

/// Null when [text] (trimmed) is an acceptable feedback message; otherwise
/// what to tell the user.
String? userFeedbackProblem(String text) {
  // The "write something first" message already covers an empty form.
  if (text.isEmpty) {
    return null;
  }
  if (text.length > userFeedbackMaxLength) {
    return 'Please keep your feedback to $userFeedbackMaxLength characters '
        'or fewer.';
  }
  return null;
}

/// The feedback box: a maroon outline with rounded corners.
final OutlineInputBorder _feedbackBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(20),
  borderSide: const BorderSide(color: Color(0xFF780000), width: 1.5),
);

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _feedbackController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;
  bool _submitted = false;

  // Offline: the box is greyed out and Send is off (feedback needs the
  // internet). A failed connectivity check counts as online.
  bool _offline = !(ConnectivityService().lastKnownOnline ?? true);
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _refreshOnline();
    _connectivitySub = ConnectivityService().onlineStream.listen((online) {
      if (mounted) setState(() => _offline = !online);
    }, onError: (_) {});
  }

  Future<void> _refreshOnline() async {
    try {
      final online = await ConnectivityService().isOnline;
      if (mounted) setState(() => _offline = !online);
    } catch (_) {}
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(OfflineStrings.of(context).unavailable)),
      );
      return;
    }
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ScreenText.of(context).writeFeedbackFirst)),
      );
      return;
    }
    final problem = userFeedbackProblem(_feedbackController.text.trim());
    if (problem != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('feedback')
          .add({
            'userId': user?.uid,
            // A guest has no account: the admin side labels these "Guest".
            if (user == null) 'source': 'guest',
            'message': _feedbackController.text.trim(),
            'rating': _rating == 0 ? null : _rating,
            'submittedAt': FieldValue.serverTimestamp(),
          })
          .timeout(Duration(seconds: 10));

      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ScreenText.of(context).couldNotSubmitFeedback)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Feedback'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: _submitted ? _buildThankYou(theme) : _buildForm(theme),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'We\'d love to hear your thoughts! Let us know what\'s working '
            'well or what could be improved.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF0EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  'How would you rate Fine Aid?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    return IconButton(
                      // Offline: the rating is greyed out, like the text box.
                      onPressed: _offline
                          ? null
                          : () => setState(() => _rating = starValue),
                      icon: Icon(
                        starValue <= _rating ? Icons.star : Icons.star_border,
                        color: _offline
                            ? Colors.grey.shade400
                            : theme.colorScheme.primary,
                        size: 40,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            ScreenText.of(context).yourFeedback,
            style: theme.textTheme.titleSmall?.copyWith(color: Colors.black),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _feedbackController,
            // Offline: greyed out and not editable.
            enabled: !_offline,
            maxLines: 6,
            // Typing or pasting stops at the maximum.
            inputFormatters: [
              LengthLimitingTextInputFormatter(userFeedbackMaxLength),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              filled: true,
              fillColor: _offline ? Colors.grey.shade200 : Colors.white,
              border: _feedbackBorder,
              enabledBorder: _feedbackBorder,
              focusedBorder: _feedbackBorder,
              hintText: 'Tell us what you think...',
              helperText: _offline
                  ? OfflineStrings.of(context).unavailable
                  : null,
              // Live count.
              counterText:
                  '${_feedbackController.text.trim().length} / '
                  '$userFeedbackMaxLength',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_isSubmitting || _offline) ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(ScreenText.of(context).submitFeedback),
          ),
        ],
      ),
    );
  }

  Widget _buildThankYou(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Image.asset(
              'assets/images/FINE_AID_Logo.png',
              width: 160,
              height: 160,
            ),
          ),

          const SizedBox(height: 16),
          Text(
            ScreenText.of(context).thankYou,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Your feedback helps us improve Fine Aid.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(ScreenText.of(context).done),
          ),
        ],
      ),
    );
  }
}
