import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/api/gemini_service.dart';
import '../../services/firebase/first_aid_content_service.dart';
import '../../services/firebase/notification_service.dart';
import '../../services/voice_input_service.dart';
import '../../services/health_profile_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/otc_filter_service.dart';
import '../../services/guest_usage_service.dart';
import '../../core/widgets/guest_gate_dialogs.dart';
import '../../core/widgets/guest_usage_badge.dart';
import '../../core/network_error.dart';
import '../../core/scope_check.dart';
import '../../data/healing_durations.dart';
import '../../data/health_profile_cautions.dart';
import '../../core/follow_up_fallback.dart';
import '../../core/widgets/voice_message_bubble.dart';
import '../../core/widgets/otc_suggestions_block.dart';
import '../../i18n/health_kit_content_tl.dart';
import '../../i18n/health_kit_locale.dart';
import '../../i18n/health_kit_ui_strings.dart';

class _FollowUpMessage {
  final String text;
  // The chat model always returns both languages (see BilingualReply) —
  // kept alongside the English text so the bubble can switch language
  // instantly when the Health Kit locale toggle changes, without a
  // re-fetch. Null for user messages, since there's nothing to translate.
  final String? tagalog;
  final bool isUser;
  final List<OtcSuggestion> otcSuggestions;
  // Set only for a voice follow-up question — the recorded clip's local
  // file path, so it can be replayed as a chat bubble. `text` is always the
  // transcript either way, so the journal and the answer pipeline never
  // need to know whether a message started out as speech or typing.
  final String? audioPath;
  const _FollowUpMessage({
    required this.text,
    this.tagalog,
    required this.isUser,
    this.otcSuggestions = const [],
    this.audioPath,
  });

  Map<String, dynamic> toJournalMap() => {
    'role': isUser ? 'user' : 'assistant',
    'text': text,
  };
}

/// A single yes/no question in a category's fixed-order question tree.
/// Answering "yes" to a red-flag question immediately shows a safety
/// interstitial before the flow continues to the next question — this is
/// all local data and logic, no network access involved.
class _Question {
  final String text;
  final bool isRedFlag;
  final String? redFlagMessage;

  const _Question({
    required this.text,
    this.isRedFlag = false,
    this.redFlagMessage,
  });
}

class _Category {
  // Matches a key in healthKitContentTl (health_kit_content_tl.dart) so
  // the Tagalog translation for this category can be looked up.
  final String id;
  final String title;
  final IconData icon;
  final List<_Question> questions;
  final List<String> steps;
  final List<String> watchFor;
  final String seekCareIf;

  const _Category({
    required this.id,
    required this.title,
    required this.icon,
    required this.questions,
    required this.steps,
    required this.watchFor,
    required this.seekCareIf,
  });
}

// Shared closing questions appended to every category so each path always
// asks at least 5 relevant questions, without padding with irrelevant
// filler — bleeding, worsening pain, and infection signs matter for any
// injury type.
const List<_Question> _sharedTailQuestions = [
  _Question(
    text:
        'Is the area bleeding heavily, or not stopping with gentle '
        'pressure after several minutes?',
    isRedFlag: true,
    redFlagMessage:
        'Bleeding that won\'t stop with gentle pressure needs '
        'urgent professional attention.',
  ),
  _Question(
    text: 'Is the pain severe, or getting worse instead of better?',
    isRedFlag: true,
    redFlagMessage:
        'Severe or worsening pain should be evaluated by a '
        'healthcare professional.',
  ),
  _Question(
    text:
        'Does the area look increasingly red or warm, or have any '
        'discharge (possible signs of infection)?',
    isRedFlag: true,
    redFlagMessage:
        'These can be early signs of infection — please have '
        'it checked by a healthcare professional.',
  ),
];

const List<String> _defaultWatchFor = [
  'Increasing redness, warmth, or swelling',
  'Pus or discharge',
  'Worsening or spreading pain',
  'Fever',
];

class _FirstAidKitScreenState extends State<FirstAidKitScreen> {
  static final List<_Category> _categories = [
    _Category(
      id: 'laceration',
      title: 'Laceration',
      icon: Icons.cut_outlined,
      questions: [
        const _Question(
          text: 'Was this caused by a dirty, rusty, or contaminated object?',
          isRedFlag: true,
          redFlagMessage:
              'Because this may involve a contaminated object, '
              'consider a tetanus check with a healthcare professional.',
        ),
        const _Question(
          text: 'Is the cut deep, or does it have gaping edges?',
          isRedFlag: true,
          redFlagMessage:
              'Deep or gaping cuts often need stitches — '
              'please have this evaluated by a professional.',
        ),
        ..._sharedTailQuestions,
      ],
      steps: [
        'Wash your hands before touching the wound.',
        'Apply gentle, firm pressure with clean gauze or cloth to control bleeding.',
        'Rinse the wound with clean running water once bleeding slows.',
        'Cover with a sterile bandage or dressing.',
        'Change the dressing daily and keep the area clean and dry.',
      ],
      watchFor: _defaultWatchFor,
      seekCareIf:
          'Bleeding doesn\'t stop, the cut is deep/gaping, or you '
          'notice signs of infection.',
    ),
    _Category(
      id: 'minor_cut',
      title: 'Minor Cut',
      icon: Icons.content_cut,
      questions: [
        const _Question(
          text: 'Is the cut on your face, hands, or over a joint?',
        ),
        const _Question(
          text: 'Is there a foreign object still stuck in the wound?',
          isRedFlag: true,
          redFlagMessage:
              'Do not try to remove embedded objects yourself '
              '— seek professional medical care.',
        ),
        ..._sharedTailQuestions,
      ],
      steps: [
        'Wash your hands and rinse the cut under clean running water.',
        'Apply gentle pressure with a clean cloth if it\'s bleeding.',
        'Apply an antiseptic if available.',
        'Cover with a small adhesive bandage.',
        'Keep the area clean and change the bandage daily.',
      ],
      watchFor: _defaultWatchFor,
      seekCareIf:
          'There\'s an embedded object, or signs of infection '
          'develop.',
    ),
    _Category(
      id: 'scratch',
      title: 'Scratch',
      icon: Icons.back_hand_outlined,
      questions: [
        const _Question(
          text: 'Was the scratch from a pet or any other animal?',
          isRedFlag: true,
          redFlagMessage:
              'Because this injury may involve animal '
              'exposure, consider seeking professional medical advice '
              '(rabies risk).',
        ),
        const _Question(text: 'Is there any swelling around the scratch?'),
        ..._sharedTailQuestions,
      ],
      steps: [
        'Wash the scratch thoroughly with soap and clean water.',
        'Apply an antiseptic if available.',
        'Cover with a clean bandage if it\'s in an area prone to friction.',
        'Monitor the area daily for the next few days.',
        'Keep the area clean and avoid scratching it further.',
      ],
      watchFor: _defaultWatchFor,
      seekCareIf: 'An animal was involved, or signs of infection develop.',
    ),
    _Category(
      id: 'abrasion',
      title: 'Abrasion',
      icon: Icons.healing_outlined,
      questions: [
        const _Question(
          text:
              'Is the scraped area contaminated with dirt or debris that '
              'won\'t rinse out?',
          isRedFlag: true,
          redFlagMessage:
              'Embedded debris that won\'t rinse clean should '
              'be checked by a professional to prevent infection.',
        ),
        const _Question(text: 'Is the abrasion larger than your palm?'),
        ..._sharedTailQuestions,
      ],
      steps: [
        'Rinse the scrape gently under clean running water.',
        'Remove any loose, visible debris carefully.',
        'Apply antiseptic ointment if available.',
        'Cover with a sterile, non-stick dressing.',
        'Change the dressing daily until healed.',
      ],
      watchFor: _defaultWatchFor,
      seekCareIf:
          'Debris won\'t rinse out, it\'s a large area, or signs of '
          'infection develop.',
    ),
    _Category(
      id: 'puncture_wound',
      title: 'Puncture Wound',
      icon: Icons.change_history,
      questions: [
        const _Question(
          text: 'Was the object a nail, needle, or something dirty/rusty?',
          isRedFlag: true,
          redFlagMessage:
              'Puncture wounds from dirty or rusty objects '
              'carry infection and tetanus risk - please seek medical care.',
        ),
        const _Question(
          text: 'Is the puncture deep?',
          isRedFlag: true,
          redFlagMessage:
              'Deep puncture wounds should be evaluated by a '
              'professional, even if bleeding looks minor.',
        ),
        ..._sharedTailQuestions,
      ],
      steps: [
        'Wash your hands, then gently wash the area with soap and water.',
        'Do not push on the wound to make it bleed "to clean it out."',
        'Apply gentle pressure with clean gauze if it\'s bleeding.',
        'Cover with a clean bandage.',
        'Watch closely for signs of infection over the next few days.',
      ],
      watchFor: _defaultWatchFor,
      seekCareIf:
          'The object was dirty/rusty, the puncture is deep, or '
          'you\'re unsure about your tetanus vaccination status.',
    ),
    _Category(
      id: 'burn',
      title: 'Burn',
      icon: Icons.local_fire_department_outlined,
      questions: [
        const _Question(
          text:
              'Is the burn larger than your palm, or on your face, '
              'hands, feet, or a joint?',
          isRedFlag: true,
          redFlagMessage:
              'Burns of this size or in these areas need '
              'professional evaluation.',
        ),
        const _Question(text: 'Are there blisters or broken skin?'),
        ..._sharedTailQuestions,
      ],
      steps: [
        'Cool the burn under cool (not ice-cold) running water for 10-20 minutes.',
        'Do not apply ice directly to the burn.',
        'Remove jewelry or tight items near the burned area.',
        'Cover loosely with a clean, non-stick dressing.',
        'Do not pop any blisters that form.',
      ],
      watchFor: _defaultWatchFor,
      seekCareIf:
          'The burn is large, deep, on a sensitive area, or shows '
          'signs of infection.',
    ),
    _Category(
      id: 'bruise',
      title: 'Bruise',
      icon: Icons.circle_outlined,
      questions: [
        const _Question(
          text:
              'Did this happen from a high-impact injury (fall, vehicle '
              'accident, heavy object)?',
          isRedFlag: true,
          redFlagMessage:
              'High-impact injuries can cause hidden damage - '
              'please seek medical evaluation.',
        ),
        const _Question(
          text:
              'Is the bruised area very swollen, misshapen, or hard to '
              'move normally?',
          isRedFlag: true,
          redFlagMessage:
              'This could indicate a fracture or deeper injury '
              '- please seek medical attention.',
        ),
        ..._sharedTailQuestions,
      ],
      steps: [
        'Rest the bruised area and avoid further impact.',
        'Apply a cold compress (wrapped, not directly on skin) for 15-20 minutes.',
        'Elevate the area above heart level if possible.',
        'After 48 hours, a warm compress can help with healing.',
        'Take note of the bruise\'s size and color over the next few days.',
      ],
      watchFor: [
        'Increasing swelling or pain',
        'Numbness or difficulty moving the area',
        'The bruise getting significantly larger',
      ],
      seekCareIf:
          'There was a high-impact cause, or the area is very '
          'swollen, misshapen, or hard to move.',
    ),
    _Category(
      id: 'swelling',
      title: 'Swelling',
      icon: Icons.bubble_chart_outlined,
      questions: [
        const _Question(
          text:
              'Did the swelling start suddenly with no clear injury '
              '(possible allergic reaction)?',
          isRedFlag: true,
          redFlagMessage:
              'Sudden, unexplained swelling can be an allergic '
              'reaction — seek medical attention right away, especially if '
              'it affects your face, lips, or throat.',
        ),
        const _Question(text: 'Is it hard to move the swollen area normally?'),
        ..._sharedTailQuestions,
      ],
      steps: [
        'Rest the swollen area.',
        'Apply a cold compress (wrapped, not directly on skin) for 15-20 minutes.',
        'Elevate the area above heart level if possible.',
        'Avoid heat or vigorous activity on the area for the first day.',
        'Monitor how the swelling changes over the next 24-48 hours.',
      ],
      watchFor: [
        'Swelling that keeps increasing',
        'Difficulty breathing or swallowing',
        'Swelling spreading to the face, lips, or throat',
      ],
      seekCareIf:
          'Swelling started suddenly with no cause, spreads to the '
          'face/throat, or comes with difficulty breathing.',
    ),
    _Category(
      id: 'rash',
      title: 'Rash',
      icon: Icons.grain_outlined,
      questions: [
        const _Question(
          text:
              'Did the rash appear suddenly after eating something new, '
              'a new medicine, or an insect bite (possible allergic '
              'reaction)?',
          isRedFlag: true,
          redFlagMessage:
              'This may be an allergic reaction - seek medical '
              'attention, especially if you have any trouble breathing or '
              'facial swelling.',
        ),
        const _Question(
          text:
              'Is the rash spreading quickly, or with difficulty '
              'breathing or facial swelling?',
          isRedFlag: true,
          redFlagMessage:
              'These are signs of a severe allergic reaction — '
              'seek emergency care immediately.',
        ),
        ..._sharedTailQuestions,
      ],
      steps: [
        'Avoid scratching the affected area.',
        'Wash the area gently with mild soap and cool water.',
        'Apply a fragrance-free moisturizer or soothing lotion if available.',
        'Avoid known irritants or allergens if you can identify one.',
        'Keep track of when the rash started and anything new you were exposed to.',
      ],
      watchFor: [
        'Rash spreading quickly',
        'Difficulty breathing or facial/throat swelling',
        'Fever alongside the rash',
      ],
      seekCareIf:
          'The rash may be an allergic reaction, is spreading '
          'quickly, or comes with breathing difficulty.',
    ),
    _Category(
      id: 'other_skin_issue',
      title: 'Other Skin Issue',
      icon: Icons.medical_information_outlined,
      questions: [
        const _Question(text: 'Is there any active bleeding?'),
        const _Question(
          text:
              'Is the affected area very painful or significantly '
              'swollen?',
        ),
        ..._sharedTailQuestions,
      ],
      steps: [
        'Keep the affected area clean.',
        'Apply gentle first aid appropriate to what you\'re seeing '
            '(cleaning, cold compress, or rest as needed).',
        'Avoid putting strain on the injured area.',
        'Monitor the area for changes over the next day.',
        'If unsure what you\'re dealing with, treat cautiously and watch '
            'closely.',
      ],
      watchFor: _defaultWatchFor,
      seekCareIf:
          'You\'re unsure about the injury, or any concerning signs '
          'develop.',
    ),
  ];

  int? _selectedCategoryIndex;
  bool _isRunningFlow = false;
  int? _resultCategoryIndex;
  bool _resultHasRedFlag = false;

  final TextEditingController _concernController = TextEditingController();
  String? _userConcern;
  final List<Map<String, dynamic>> _qaHistory = [];
  final List<String> _redFlagMessages = [];

  final TextEditingController _chatController = TextEditingController();
  final List<_FollowUpMessage> _followUpMessages = [];
  bool _isSendingFollowUp = false;

  final VoiceInputService _voiceInput = VoiceInputService();
  bool _isRecording = false;
  Duration _recordingElapsed = Duration.zero;
  double _recordingLevel = 0;
  Timer? _recordingTimer;
  StreamSubscription<double>? _amplitudeSubscription;

  bool _isSaving = false;
  bool _savedToJournal = false;
  String? _savedJournalEntryId;
  bool _hasUnsavedFollowUps = false;

  List<String> _healthCautions = [];

  HealthKitLocale _locale = HealthKitLocale.en;

  @override
  void initState() {
    super.initState();
    _loadLocale();
    _loadHealthCautions();
  }

  Future<void> _loadHealthCautions() async {
    final profile = await HealthProfileService().getHealthProfile();
    if (!mounted) return;
    final cautions = healthProfileCautions(profile);
    if (cautions.isNotEmpty) setState(() => _healthCautions = cautions);
  }

  Future<void> _loadLocale() async {
    final locale = await loadHealthKitLocale();
    if (!mounted) return;
    setState(() => _locale = locale);
  }

  void _setLocale(HealthKitLocale locale) {
    if (locale == _locale) return;
    setState(() => _locale = locale);
    saveHealthKitLocale(locale);
  }

  String _ui(String key) => HealthKitStrings.of(key, _locale);

  CategoryTranslationTl? _translation(_Category category) =>
      _locale == HealthKitLocale.tl ? healthKitContentTl[category.id] : null;

  String _categoryTitle(_Category category) =>
      _translation(category)?.title ?? category.title;

  String _questionText(_Category category, int index) {
    final questions = _translation(category)?.questions;
    if (questions != null && index < questions.length) {
      return questions[index].text;
    }
    return category.questions[index].text;
  }

  String _redFlagMessageFor(_Category category, int index, String fallback) {
    final questions = _translation(category)?.questions;
    if (questions != null && index < questions.length) {
      return questions[index].redFlagMessage ?? fallback;
    }
    return fallback;
  }

  List<String> _steps(_Category category) =>
      _translation(category)?.steps ?? category.steps;

  List<String> _watchFor(_Category category) =>
      _translation(category)?.watchFor ?? category.watchFor;

  String _seekCareIf(_Category category) =>
      _translation(category)?.seekCareIf ?? category.seekCareIf;

  // The chat model always returns both languages — the bot's bubble
  // switches immediately with the toggle. A user's own message is shown
  // exactly as they typed or spoke it, since there's no translation of it.
  String _displayFollowUpText(_FollowUpMessage message) {
    if (message.isUser) return message.text;
    if (_locale == HealthKitLocale.tl &&
        message.tagalog != null &&
        message.tagalog!.trim().isNotEmpty) {
      return message.tagalog!;
    }
    return message.text;
  }

  @override
  void dispose() {
    _concernController.dispose();
    _chatController.dispose();
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _voiceInput.dispose();
    super.dispose();
  }

  Future<bool> _askQuestion(String text, int number, int total) async {
    final answer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          HealthKitStrings.questionDialogTitle(number, total, _locale),
        ),
        content: Text(text),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_ui('no')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_ui('yes')),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  Future<void> _showRedFlagInterstitial(String message) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(_ui('redFlagInterstitialTitle'))),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_ui('continueLabel')),
          ),
        ],
      ),
    );
  }

  Future<void> _startQuestions() async {
    final index = _selectedCategoryIndex;
    if (index == null) return;

    setState(() {
      _isRunningFlow = true;
      _resultCategoryIndex = null;
      _userConcern = _concernController.text.trim().isEmpty
          ? null
          : _concernController.text.trim();
      _qaHistory.clear();
      _redFlagMessages.clear();
    });

    final category = _categories[index];
    var hasRedFlag = false;

    for (var i = 0; i < category.questions.length; i++) {
      if (!mounted) return;
      final question = category.questions[i];
      final answeredYes = await _askQuestion(
        _questionText(category, i),
        i + 1,
        category.questions.length,
      );
      _qaHistory.add({
        'question': question.text,
        'answer': answeredYes ? 'Yes' : 'No',
      });

      if (answeredYes && question.isRedFlag) {
        hasRedFlag = true;
        final fallback =
            question.redFlagMessage ??
            'Based on your answer, this may need professional evaluation.';
        final message = _redFlagMessageFor(category, i, fallback);
        _redFlagMessages.add(message);
        if (!mounted) return;
        await _showRedFlagInterstitial(message);
      }
    }

    if (!mounted) return;
    setState(() {
      _isRunningFlow = false;
      _resultCategoryIndex = index;
      _resultHasRedFlag = hasRedFlag;
    });
  }

  void _reset() {
    setState(() {
      _selectedCategoryIndex = null;
      _resultCategoryIndex = null;
      _isRunningFlow = false;
      _userConcern = null;
      _concernController.clear();
      _qaHistory.clear();
      _redFlagMessages.clear();
      _followUpMessages.clear();
      _savedToJournal = false;
      _savedJournalEntryId = null;
      _hasUnsavedFollowUps = false;
    });
  }

  Future<void> _handleFollowUpSend() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isSendingFollowUp) return;
    _chatController.clear();
    await _sendFollowUp(text);
  }

  Future<void> _sendFollowUp(String text, {String? audioPath}) async {
    if (text.isEmpty || _isSendingFollowUp) return;

    // Deliberately no local out-of-scope pre-check here (unlike the
    // standalone chatbot) — this screen only reaches the follow-up input
    // after a category is already selected, so a message like "I have a
    // headache" is very plausibly ABOUT that category even without
    // repeating wound-related words. A keyword-only check can't see that
    // context and would wrongly refuse it; the shared system prompt's own
    // scope/borderline-case judgment, which DOES see the category context
    // (passed below), is the right place to decide here.
    final isGuest = FirebaseAuth.instance.currentUser == null;
    if (isGuest && await GuestUsageService.instance.hasReachedLimit()) {
      if (!mounted) return;
      await showGuestUsageLimitDialog(context);
      return;
    }

    setState(() {
      _followUpMessages.add(
        _FollowUpMessage(text: text, isUser: true, audioPath: audioPath),
      );
      _isSendingFollowUp = true;
    });

    final online = await ConnectivityService().isOnline;
    if (!online) {
      if (!mounted) return;
      setState(() {
        _followUpMessages.add(
          _FollowUpMessage(text: noInternetMessage, isUser: false),
        );
        _isSendingFollowUp = false;
      });
      return;
    }

    final category = _resultCategoryIndex != null
        ? _categories[_resultCategoryIndex!]
        : null;
    final woundContext = category == null
        ? null
        : 'Category: ${category.title}\n'
              'First aid steps given: ${category.steps.join(' ')}\n'
              'Warning signs: ${category.watchFor.join(', ')}';

    String response;
    String? responseTagalog;
    List<OtcSuggestion> otcSuggestions = const [];
    try {
      final contextualQuery = [
        if (category != null) category.title,
        text,
      ].join(' ');
      final referenceContext = await FirstAidContentService()
          .buildReferenceContext(contextualQuery)
          .timeout(const Duration(seconds: 15));
      final raw = await GeminiService()
          .sendChatMessage(
            text,
            referenceContext: referenceContext,
            woundContext: woundContext,
          )
          .timeout(const Duration(seconds: 20));
      final parsed = parseBilingualReply(raw);
      final english = parsed.english.trim();
      response = english.isNotEmpty ? english : randomFollowUpFallbackMessage();
      final tagalog = parsed.tagalog?.trim();
      responseTagalog = (tagalog != null && tagalog.isNotEmpty)
          ? tagalog
          : null;
      otcSuggestions = await OtcFilterService.instance.filter(
        parsed.otcSuggestions,
      );
      if (isGuest && !isRefusalReply(response)) {
        await GuestUsageService.instance.recordSuccessfulUse();
      }
    } catch (e, st) {
      logFollowUpError('FirstAidKit', e, st);
      response = isNetworkError(e)
          ? noInternetMessage
          : randomFollowUpFallbackMessage();
    }

    if (!mounted) return;
    setState(() {
      _followUpMessages.add(
        _FollowUpMessage(
          text: response,
          tagalog: responseTagalog,
          isUser: false,
          otcSuggestions: otcSuggestions,
        ),
      );
      _isSendingFollowUp = false;
      if (_savedJournalEntryId != null) _hasUnsavedFollowUps = true;
    });
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startVoiceRecording() async {
    if (_isSendingFollowUp || _isRecording) return;

    final available = await _voiceInput.isAvailable;
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "I couldn't access speech recognition on this device - check "
            'that microphone permission is allowed, or type your question '
            'instead.',
          ),
        ),
      );
      return;
    }

    await _voiceInput.start();
    if (!mounted) return;
    _amplitudeSubscription = _voiceInput.amplitudeStream().listen((level) {
      if (mounted) setState(() => _recordingLevel = level);
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingElapsed += const Duration(seconds: 1));
      }
    });
    setState(() {
      _isRecording = true;
      _recordingElapsed = Duration.zero;
    });
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await _amplitudeSubscription?.cancel();
    await _voiceInput.cancel();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingElapsed = Duration.zero;
      _recordingLevel = 0;
    });
  }

  Future<void> _finishVoiceRecording() async {
    _recordingTimer?.cancel();
    await _amplitudeSubscription?.cancel();
    final result = await _voiceInput.stop();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingElapsed = Duration.zero;
      _recordingLevel = 0;
    });

    if (result.transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.audioPath == null
                ? "I couldn't record that - check microphone permission "
                      'and try again, or type your question instead.'
                : "I recorded that, but couldn't make out the words - try "
                      'again, speak a bit closer to the mic, or type your '
                      'question instead.',
          ),
        ),
      );
      return;
    }

    await _sendFollowUp(result.transcript, audioPath: result.audioPath);
  }

  Future<void> _saveToJournal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await showGuestSaveGateDialog(context);
      return;
    }
    final index = _resultCategoryIndex;
    if (index == null) return;
    final category = _categories[index];

    setState(() => _isSaving = true);

    try {
      final stepsText = category.steps
          .asMap()
          .entries
          .map((e) => '${e.key + 1}. ${e.value}')
          .join('\n');
      final description =
          'FIRST AID STEPS:\n$stepsText\n\n'
          'WATCH FOR:\n${category.watchFor.map((w) => '- $w').join('\n')}\n\n'
          'SEEK CARE IF: ${category.seekCareIf}';

      final journalData = <String, dynamic>{
        'title': 'First Aid Assistant Session',
        'description': description,
        'classification': category.title,
        'category': category.title,
        'source': 'first_aid_assistant',
        'userConcern': _userConcern,
        'questionsAndAnswers': _qaHistory,
        'redFlags': _redFlagMessages,
        'firstAidSteps': category.steps,
        'watchFor': category.watchFor,
        'seekCareIf': category.seekCareIf,
        'hasRedFlag': _resultHasRedFlag,
        'followUpConversation': _followUpMessages
            .map((m) => m.toJournalMap())
            .toList(),
        'imageUrls': const <String>[],
        'imageCount': 0,
        'severity': null,
        'remindMe': false,
      };

      if (_savedJournalEntryId == null) {
        journalData['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('journalEntries')
            .add(journalData)
            .timeout(const Duration(seconds: 10));

        final healingDays = healingDurationDays[category.title];
        if (healingDays != null && mounted) {
          await NotificationService().ensureHealingReminderPermission(context);
          await NotificationService().scheduleHealingCheckIn(
            entryId: docRef.id,
            classification: category.title,
            healingDays: healingDays,
          );
        }

        if (mounted) {
          setState(() {
            _savedToJournal = true;
            _savedJournalEntryId = docRef.id;
            _hasUnsavedFollowUps = false;
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session saved to Health Journal.')),
          );
        }
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('journalEntries')
            .doc(_savedJournalEntryId)
            .update({
              'userConcern': journalData['userConcern'],
              'followUpConversation': journalData['followUpConversation'],
            })
            .timeout(const Duration(seconds: 10));

        if (mounted) {
          setState(() {
            _hasUnsavedFollowUps = false;
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Journal entry updated.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save to journal. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'First Aid Health Kit',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildLanguageToggle(theme),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _ui('bannerBody'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _ui('categoryPrompt'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryIndex,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                      ),
                      hint: Text(_ui('categoryHint')),
                      items: List.generate(
                        _categories.length,
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _categories[i].icon,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(_categoryTitle(_categories[i])),
                            ],
                          ),
                        ),
                      ),
                      onChanged: _isRunningFlow
                          ? null
                          : (index) {
                              if (index == null) return;
                              setState(() {
                                _selectedCategoryIndex = index;
                                _resultCategoryIndex = null;
                              });
                            },
                    ),
                    if (_selectedCategoryIndex != null &&
                        !_isRunningFlow &&
                        _resultCategoryIndex == null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _ui('concernLabel'),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _concernController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: _ui('concernHint'),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _startQuestions,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                        child: Text(_ui('startQuestions')),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_isRunningFlow)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_resultCategoryIndex != null)
                      _buildResult(theme, _categories[_resultCategoryIndex!]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageToggle(ThemeData theme) {
    return Semantics(
      label: _ui('languageToggleLabel'),
      child: SegmentedButton<HealthKitLocale>(
        segments: const [
          ButtonSegment(value: HealthKitLocale.en, label: Text('EN')),
          ButtonSegment(value: HealthKitLocale.tl, label: Text('TL')),
        ],
        selected: {_locale},
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onSelectionChanged: (selection) => _setLocale(selection.first),
      ),
    );
  }

  /// Short cautions derived from the user's onboarding Health Profile
  /// (diabetes, bleeding disorders, severe allergies) — an additive nudge
  /// alongside the standard first aid steps, not a replacement for them.
  Widget _buildHealthCautionBox(ThemeData theme) {
    if (_healthCautions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Based on Your Health Profile',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ..._healthCautions.map(
              (c) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  c,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(ThemeData theme, _Category category) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Icon(category.icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _categoryTitle(category),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (_userConcern != null) ...[
            const SizedBox(height: 12),
            Text(
              _ui('yourConcern'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(_userConcern!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          if (_resultHasRedFlag) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _ui('redFlagSummary'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildHealthCautionBox(theme),
          Text(
            _ui('basicFirstAidSteps'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._steps(category).asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.key + 1}. ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(e.value, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _ui('watchFor'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ..._watchFor(category).map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(w, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_ui('seekCareIfPrefix')}${_seekCareIf(category)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _ui('resultDisclaimer'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          if (_savedToJournal && !_hasUnsavedFollowUps)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _ui('savedToJournal'),
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveToJournal,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _hasUnsavedFollowUps ? Icons.sync : Icons.save_outlined,
                      size: 18,
                    ),
              label: Text(
                _isSaving
                    ? _ui('saving')
                    : _hasUnsavedFollowUps
                    ? _ui('updateJournalEntry')
                    : _ui('saveToJournal'),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          const SizedBox(height: 16),
          _buildFollowUpSection(theme),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _reset,
            child: Text(_ui('chooseDifferentInjury')),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _ui('askFollowUp'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            const GuestUsageBadge(),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _ui('followUpSubtitle'),
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 10),
        ..._followUpMessages.map(
          (m) => Align(
            alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: m.isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.audioPath != null) ...[
                    VoiceMessageBubble(
                      audioPath: m.audioPath!,
                      isUser: m.isUser,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    _displayFollowUpText(m),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: m.isUser ? Colors.white : null,
                      fontStyle: m.audioPath != null ? FontStyle.italic : null,
                    ),
                  ),
                  if (!m.isUser && m.otcSuggestions.isNotEmpty)
                    OtcSuggestionsBlock(suggestions: m.otcSuggestions),
                ],
              ),
            ),
          ),
        ),
        if (_isSendingFollowUp)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Thinking…',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        _buildFollowUpInputBar(theme),
      ],
    );
  }

  Widget _buildFollowUpInputBar(ThemeData theme) {
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              tooltip: 'Cancel recording',
              onPressed: _cancelVoiceRecording,
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 0.85 + _recordingLevel * 0.45),
              duration: const Duration(milliseconds: 150),
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: const SizedBox(
                  width: 14,
                  height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Listening… ${_formatElapsed(_recordingElapsed)}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            IconButton(
              icon: Icon(Icons.check_circle, color: theme.colorScheme.primary),
              tooltip: 'Stop and send',
              onPressed: _finishVoiceRecording,
            ),
          ],
        ),
      );
    }

    final hasText = _chatController.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _chatController,
                decoration: InputDecoration(
                  hintText: _ui('followUpHint'),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _handleFollowUpSend(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.mic, color: theme.colorScheme.primary),
            tooltip: 'Record a follow-up question',
            onPressed: _isSendingFollowUp ? null : _startVoiceRecording,
          ),
          IconButton(
            icon: Icon(Icons.send, color: theme.colorScheme.primary),
            tooltip: 'Send',
            onPressed: (_isSendingFollowUp || !hasText)
                ? null
                : _handleFollowUpSend,
          ),
        ],
      ),
    );
  }
}

class FirstAidKitScreen extends StatefulWidget {
  const FirstAidKitScreen({super.key});

  @override
  State<FirstAidKitScreen> createState() => _FirstAidKitScreenState();
}
