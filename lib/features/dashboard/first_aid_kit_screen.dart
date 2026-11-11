import '../../core/widgets/first_aid_step_list.dart';
import '../../core/widgets/icon_popup.dart';
import '../../i18n/offline_strings.dart';
import '../../services/connectivity_service.dart';
import '../../data/first_aid_step_images.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/health_profile_service.dart';
import '../../data/first_aid_guides.dart';
import '../../core/widgets/health_profile_box.dart';
import '../../i18n/first_aid_guides_tl.dart';
import '../../i18n/health_kit_content_tl.dart';
import '../../i18n/app_language.dart';
import '../../i18n/health_kit_locale.dart';
import '../../i18n/health_kit_ui_strings.dart';

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
  // The picture shown beside the category name (assets/images/health_kit/).
  final String image;
  final List<_Question> questions;
  final List<String> watchFor;
  final String seekCareIf;

  const _Category({
    required this.id,
    required this.title,
    required this.image,
    required this.questions,
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

// The screen's soft background, behind the white cards.
const Color _pageBackground = Color(0xFFF6F7F5);

class _FirstAidKitScreenState extends State<FirstAidKitScreen> {
  static final List<_Category> _categories = [
    _Category(
      id: 'laceration',
      title: 'Laceration',
      image: 'assets/images/health_kit/Laceration.png',
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
      watchFor: _defaultWatchFor,
      seekCareIf:
          'Bleeding doesn\'t stop, the cut is deep/gaping, or you '
          'notice signs of infection.',
    ),
    _Category(
      id: 'minor_cut',
      title: 'Minor Cut',
      image: 'assets/images/health_kit/Minor_cut.png',
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
      watchFor: _defaultWatchFor,
      seekCareIf:
          'There\'s an embedded object, or signs of infection '
          'develop.',
    ),
    _Category(
      id: 'scratch',
      title: 'Scratch',
      image: 'assets/images/health_kit/Scratch.png',
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
      watchFor: _defaultWatchFor,
      seekCareIf: 'An animal was involved, or signs of infection develop.',
    ),
    _Category(
      id: 'abrasion',
      title: 'Abrasion',
      image: 'assets/images/health_kit/Abrasion.png',
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
      watchFor: _defaultWatchFor,
      seekCareIf:
          'Debris won\'t rinse out, it\'s a large area, or signs of '
          'infection develop.',
    ),
    _Category(
      id: 'puncture_wound',
      title: 'Puncture Wound',
      image: 'assets/images/health_kit/Puncture_wound.png',
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
      watchFor: _defaultWatchFor,
      seekCareIf:
          'The object was dirty/rusty, the puncture is deep, or '
          'you\'re unsure about your tetanus vaccination status.',
    ),
    _Category(
      id: 'burn',
      title: 'Burn',
      image: 'assets/images/health_kit/Burn.png',
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
      watchFor: _defaultWatchFor,
      seekCareIf:
          'The burn is large, deep, on a sensitive area, or shows '
          'signs of infection.',
    ),
    _Category(
      id: 'bruise',
      title: 'Bruise',
      image: 'assets/images/health_kit/Bruise.png',
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
      image: 'assets/images/health_kit/Swelling.png',
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
      image: 'assets/images/health_kit/Rash.png',
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
      image: 'assets/images/health_kit/Other_skin_issue.png',
      questions: [
        const _Question(text: 'Is there any active bleeding?'),
        const _Question(
          text:
              'Is the affected area very painful or significantly '
              'swollen?',
        ),
        ..._sharedTailQuestions,
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

  Map<String, dynamic>? _profile;

  // The Health Kit follows the app-wide language (Settings > Language). All of
  // its text is bundled with the app, so Filipino also works offline.
  HealthKitLocale get _locale => AppLanguageScope.isTagalog(context)
      ? HealthKitLocale.tl
      : HealthKitLocale.en;

  @override
  void initState() {
    super.initState();
    _loadHealthCautions();
    // Opened without internet: say who the Health Kit is for, first.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showOfflineNotice());
  }

  /// Offline Mode: "This is only for users with no recognized health
  /// conditions ...". Shown each time the Health Kit opens offline.
  Future<void> _showOfflineNotice() async {
    if (!mounted || ConnectivityService().lastKnownOnline != false) return;
    final s = OfflineStrings.of(context);
    await showIconPopup(
      context,
      badge: const PopupBadge(icon: Icons.medical_services_outlined),
      title: s.kitNoticeTitle,
      body: [
        Text(
          s.kitNoticeBody,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
      buttonLabel: s.understood,
      dismissible: false,
    );
  }

  Future<void> _loadHealthCautions() async {
    final profile = await HealthProfileService().getHealthProfile();
    if (!mounted) return;
    if (profile != null) setState(() => _profile = profile);
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

  // The Before / During / After guide for [category] in the current language
  // (English if a Tagalog version is somehow missing).
  List<GuideStep> _guide(_Category category) =>
      (_locale == HealthKitLocale.tl ? firstAidGuidesTl[category.id] : null) ??
      firstAidGuides[category.id] ??
      const [];

  List<Widget> _buildGuide(ThemeData theme, _Category category) {
    final guide = _guide(category);
    // The picture for a step is chosen from its English wording, so the
    // Tagalog guide (same steps, same order) gets the same pictures.
    final english = firstAidGuides[category.id] ?? const <GuideStep>[];
    return [
      FirstAidStepList(
        steps: [
          for (var i = 0; i < guide.length; i++)
            PhasedStep(
              phase: guide[i].phase,
              text: guide[i].text,
              why: guide[i].why,
              imageKey: firstAidStepImageKey(
                i < english.length ? english[i].text : guide[i].text,
              ),
            ),
        ],
        phaseLabel: (phase) => _ui('phase_${phase.name}'),
        whyLabel: _ui('whyLabel'),
        numbered: true,
      ),
    ];
  }

  List<String> _watchFor(_Category category) =>
      _translation(category)?.watchFor ?? category.watchFor;

  String _seekCareIf(_Category category) =>
      _translation(category)?.seekCareIf ?? category.seekCareIf;

  @override
  void dispose() {
    super.dispose();
  }

  /// Yes / No, or null when the person closes the box with the X (the check
  /// is cancelled: that is not an answer).
  Future<bool?> _askQuestion(String text, int number, int total) async {
    final answer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  HealthKitStrings.questionDialogTitle(number, total, _locale),
                  style: const TextStyle(
                    color: Color(0xFF700509),
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF666666)),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: Text(
          text,
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          // No (outlined) and Yes (filled): two separate pills, as designed.
          SizedBox(
            width: 112,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_ui('no')),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_ui('yes')),
            ),
          ),
        ],
      ),
    );
    return answer;
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
    });

    final category = _categories[index];
    var hasRedFlag = false;

    for (var i = 0; i < category.questions.length; i++) {
      if (!mounted) return;
      final question = category.questions[i];
      final answer = await _askQuestion(
        _questionText(category, i),
        i + 1,
        category.questions.length,
      );
      if (!mounted) return;
      if (answer == null) {
        // Closed with the X: stop here and go back to the injury list.
        _reset();
        return;
      }
      final answeredYes = answer;

      if (answeredYes && question.isRedFlag) {
        hasRedFlag = true;
        final fallback =
            question.redFlagMessage ??
            'Based on your answer, this may need professional evaluation.';
        final message = _redFlagMessageFor(category, i, fallback);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _pageBackground,
      body: Column(
        children: [
          // Maroon header: back, title, language.
          Container(
            width: double.infinity,
            color: theme.colorScheme.primary,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 60,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'First Aid Health Kit',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                    // Same width as the back button, so the title stays centred.
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_resultCategoryIndex == null && !_isRunningFlow)
                    ..._buildChooser(theme),
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
    );
  }

  /// The offline banner, the question, and one card per injury type.
  List<Widget> _buildChooser(ThemeData theme) {
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ui('bannerTitle'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _ui('bannerSubtitle'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.medical_services, color: Colors.white, size: 44),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text(
        _ui('categoryPrompt'),
        style: theme.textTheme.titleSmall?.copyWith(color: Colors.black),
      ),
      const SizedBox(height: 2),
      Text(_ui('categorySubtitle'), style: theme.textTheme.bodyMedium),
      const SizedBox(height: 16),
      // Wide, low cards (the picture, then the name and the arrow). Their
      // height follows the width (the picture is about three quarters of the
      // card) and the text size, so nothing overflows on a small phone, a
      // tablet or with a larger font.
      LayoutBuilder(
        builder: (context, box) {
          const gap = 14.0;
          final cardWidth = (box.maxWidth - gap) / 2;
          final pictureHeight = (cardWidth - 24) * 0.78 * (278 / 480);
          final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              mainAxisExtent: 12 + pictureHeight + 8 + 40 * textScale + 12,
            ),
            itemBuilder: (context, i) => _buildCategoryCard(theme, i),
          );
        },
      ),
    ];
  }

  Widget _buildCategoryCard(ThemeData theme, int index) {
    final category = _categories[index];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _isRunningFlow ? null : () => _chooseCategory(index),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The picture takes about three quarters of the card, on the
              // left; the arrow sits under the rest.
              FractionallySizedBox(
                widthFactor: 0.78,
                alignment: Alignment.centerLeft,
                child: AspectRatio(
                  aspectRatio: 480 / 278,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      category.image,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _categoryTitle(category),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFFF8C7C0),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A tap on an injury card goes straight to its questions (the Health Kit
  /// works offline, so there is nothing to describe or save).
  Future<void> _chooseCategory(int index) async {
    if (_isRunningFlow) return;
    setState(() {
      _selectedCategoryIndex = index;
      _resultCategoryIndex = null;
    });
    await _startQuestions();
  }

  /// The blue "Based on Your Health Profile" box (see [HealthProfileBox]): the
  /// conditions in the profile and a short caution for each, an additive nudge
  /// alongside the standard first aid steps, not a replacement for them.
  Widget _buildHealthCautionBox(ThemeData theme) => HealthProfileBox(
    profile: _profile,
    tagalog: _locale == HealthKitLocale.tl,
    bottomPadding: 16,
  );

  Widget _buildResult(ThemeData theme, _Category category) {
    final primary = theme.colorScheme.primary;
    final summary = _ui('redFlagSummary');
    final cut = summary.indexOf('. ');
    final summaryHead = cut > 0 ? summary.substring(0, cut + 1) : summary;
    final summaryRest = cut > 0 ? summary.substring(cut + 2) : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_resultHasRedFlag) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summaryHead,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: primary,
                        ),
                      ),
                      if (summaryRest.isNotEmpty)
                        Text(
                          summaryRest,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        // The injury: its name (and the person's own words) beside its picture.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _categoryTitle(category),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  category.image,
                  width: 120,
                  height: 70,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 120, height: 70),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildHealthCautionBox(theme),
        Text(
          _ui('basicFirstAidSteps'),
          style: theme.textTheme.titleSmall?.copyWith(color: Colors.black),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._buildGuide(theme, category),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE797),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ui('watchFor'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._watchFor(category).map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(
                              child: Text(w, style: theme.textTheme.bodySmall),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD9D9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: primary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_ui('seekCareIfPrefix')}${_seekCareIf(category)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _ui('resultDisclaimer'),
          style: theme.textTheme.labelSmall?.copyWith(
            color: const Color(0xFF8F8584),
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _reset,
          child: Text(_ui('chooseDifferentInjury')),
        ),
      ],
    );
  }
}

class FirstAidKitScreen extends StatefulWidget {
  const FirstAidKitScreen({super.key});

  @override
  State<FirstAidKitScreen> createState() => _FirstAidKitScreenState();
}
