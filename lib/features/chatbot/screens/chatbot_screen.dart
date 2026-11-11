import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/api/gemini_service.dart';
import '../../../data/health_context.dart';
import '../../../services/firebase/storage_service.dart';
import '../../../services/image_compressor.dart';
import '../../camera/screens/ai_camera_screen.dart';
import '../../../i18n/chat_upload_strings.dart';
import '../../../core/photo_permission.dart';
import '../../../core/nearby_intent.dart';
import '../../../core/widgets/nearby_healthcare_sheet.dart';
import '../../../i18n/nearby_strings.dart';
import '../../../services/firebase/first_aid_content_service.dart';
import '../../../i18n/app_language.dart';
import '../../../i18n/chat_strings.dart';
import '../../../services/otc_filter_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/guest_usage_service.dart';
import '../../../core/widgets/otc_suggestions_block.dart';
import '../../../core/widgets/guest_gate_dialogs.dart';
import '../../../core/widgets/guest_usage_badge.dart';
import '../../../core/network_error.dart';
import '../../../services/local_profile_photo.dart';
import '../../../core/scope_check.dart';

class _ChatMessage {
  final String text;
  final String? tagalog;
  final bool isUser;
  final bool isUrgent;
  final List<OtcSuggestion> otcSuggestions;
  // Set only for a photo the user attached — its local file path, shown as
  // an image in the bubble.
  final String? imagePath;
  // True for an answer that points to nearby healthcare: the bubble then
  // carries the "Find Nearby Healthcare" button.
  final bool showNearby;

  _ChatMessage({
    required this.text,
    this.tagalog,
    required this.isUser,
    this.isUrgent = false,
    this.otcSuggestions = const [],
    this.imagePath,
    this.showNearby = false,
  });
}

class ChatbotScreen extends StatefulWidget {
  final String? initialContext;

  /// When opened from an existing Health Journal entry (eg, via "Need
  /// More Help"), this is that entry's document ID — every question/
  /// answer exchange in this session gets appended to that same entry's
  /// `followUpConversation`, rather than being lost or creating a new
  /// entry. Left null for a normal, standalone chat session.
  final String? journalEntryId;

  /// True when opened from "Need More Help" for an entry whose recovery is
  /// not progressing: the chat then opens with nearby healthcare options.
  final bool showNearbyFirst;

  const ChatbotScreen({
    super.key,
    this.initialContext,
    this.journalEntryId,
    this.showNearbyFirst = false,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  // A photo the user picked but hasn't sent yet (preview + remove), and
  // whether it's being uploaded to Firebase Storage right now.
  XFile? _attachment;
  bool _isUploading = false;

  // What the person already saved (Health Profile, latest journal entries),
  // sent with every question so the answers fit them. Null = nothing stored.
  String? _healthContext;

  @override
  void initState() {
    super.initState();
    loadChatHealthContext().then((text) {
      if (mounted) _healthContext = text;
    });
    _messages.add(
      _ChatMessage(
        text: widget.initialContext != null
            ? ChatStrings.en.greetingFor(widget.initialContext!)
            : ChatStrings.en.greetingGeneral,
        tagalog: widget.initialContext != null
            ? ChatStrings.tl.greetingFor(widget.initialContext!)
            : ChatStrings.tl.greetingGeneral,
        isUser: false,
      ),
    );
    if (widget.showNearbyFirst) {
      _messages.add(
        _ChatMessage(
          text: NearbyStrings.en.worseningChatReply,
          tagalog: NearbyStrings.tl.worseningChatReply,
          isUser: false,
          showNearby: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    final attachment = _attachment;
    if (text.isEmpty && attachment == null) return;

    if (attachment != null) {
      final uploaded = await _uploadAttachment(attachment);
      // On failure keep the photo and the typed text so they can retry.
      if (!uploaded) return;
    }
    _inputController.clear();
    if (text.isNotEmpty) await _sendMessage(text);
  }

  /// Lets the user attach an image: take one with the in-app camera or pick
  /// one from the gallery. Images only. Needs an account, since the photo
  /// is saved to the user's own Firebase Storage folder.
  Future<void> _pickAttachment() async {
    final s = ChatUploadStrings.of(context);
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.loginRequired)));
      return;
    }

    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(s.takePhoto),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(s.chooseFromGallery),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    // Ask for the permission first (with its explanation). Without it
    // nothing is opened and nothing is uploaded; if it is refused an
    // "Access Required" pop-up offers Open Settings / Cancel.
    final allowed = await ensurePhotoPermission(
      context,
      source == 'camera' ? PhotoSource.camera : PhotoSource.gallery,
    );
    if (!allowed || !mounted) return;

    String? path;
    if (source == 'camera') {
      path = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => const AiCameraScreen(captureOnly: true),
        ),
      );
    } else {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) path = await compressImageFile(picked.path);
    }
    if (path != null && mounted) setState(() => _attachment = XFile(path!));
  }

  /// Uploads the attached photo to Firebase Storage (the user's own journal
  /// image folder) and shows it in the chat. Returns false if it fails.
  Future<bool> _uploadAttachment(XFile attachment) async {
    final s = ChatUploadStrings.of(context);
    setState(() => _isUploading = true);
    try {
      await StorageService()
          .uploadJournalImage(
            attachment.path,
            'help_${widget.journalEntryId ?? 'general'}',
          )
          .timeout(const Duration(seconds: 60));
      if (!mounted) return false;
      final hasText = _inputController.text.trim().isNotEmpty;
      setState(() {
        _messages.add(
          _ChatMessage(text: '', isUser: true, imagePath: attachment.path),
        );
        // With a typed question the AI's answer follows; a photo on its own
        // just gets a confirmation that it was saved.
        if (!hasText) {
          _messages.add(_ChatMessage(text: s.savedMessage, isUser: false));
        }
        _attachment = null;
      });
      _scrollToBottom();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.uploadFailed)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || _isTyping) return;

    // Scope check first — free, no network, no quota — so it works
    // offline and never counts against a guest's daily limit.
    if (looksObviouslyOutOfScope(text)) {
      setState(() {
        _messages.add(_ChatMessage(text: text, isUser: true));
        _messages.add(
          _ChatMessage(text: outOfScopeRefusalMessage, isUser: false),
        );
      });
      _scrollToBottom();
      return;
    }

    final isGuest = FirebaseAuth.instance.currentUser == null;
    if (isGuest && await GuestUsageService.instance.hasReachedLimit()) {
      if (!mounted) return;
      await showGuestUsageLimitDialog(context);
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();

    // "Where is the nearest hospital / clinic / pharmacy…?": answered with the
    // nearby healthcare options (works offline, no AI call needed).
    if (asksForNearbyHealthcare(text)) {
      setState(() {
        _messages.add(
          _ChatMessage(
            text: NearbyStrings.en.chatNearbyReply,
            tagalog: NearbyStrings.tl.chatNearbyReply,
            isUser: false,
            showNearby: true,
          ),
        );
        _isTyping = false;
      });
      _scrollToBottom();
      return;
    }

    final online = await ConnectivityService().isOnline;
    if (!online) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: noInternetMessage, isUser: false));
        _isTyping = false;
      });
      _scrollToBottom();
      return;
    }

    String english;
    String? tagalog;
    bool isUrgent = false;
    bool suggestNearby = false;
    List<OtcSuggestion> otcSuggestions = const [];
    try {
      // RAG: look up relevant chunks from the firstAidContent Firestore
      // collection before asking Gemini, so the answer is grounded in the
      // reference books instead of general model knowledge.
      final referenceContext = await FirstAidContentService()
          .buildReferenceContext(text);
      final raw = await GeminiService().sendChatMessage(
        text,
        referenceContext: referenceContext,
        healthContext: _healthContext,
      );
      final parsed = parseBilingualReply(raw);
      english = parsed.english;
      tagalog = parsed.tagalog;
      isUrgent = parsed.isUrgent;
      suggestNearby = parsed.suggestNearby;
      otcSuggestions = await OtcFilterService.instance.filter(
        parsed.otcSuggestions,
      );
      if (isGuest && !isRefusalReply(english)) {
        await GuestUsageService.instance.recordSuccessfulUse();
      }
    } catch (e) {
      // A real network failure between the connectivity check above and
      // this request (or a request that simply hung) still shouldn't show
      // a mock/canned response as if it were a genuine answer.
      english = isNetworkError(e)
          ? noInternetMessage
          : _generateMockResponse(text);
    }

    if (!mounted) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          text: english,
          tagalog: tagalog,
          isUser: false,
          isUrgent: isUrgent,
          otcSuggestions: otcSuggestions,
          showNearby: suggestNearby,
        ),
      );
      _isTyping = false;
    });
    _scrollToBottom();

    _appendToJournalEntry(userText: text, assistantText: english);
  }

  /// Appends this exchange to the linked journal entry's follow-up
  /// conversation, if this chat was opened from one. Uses arrayUnion so
  /// concurrent/rapid messages never overwrite each other's entries, and
  /// silently no-ops if this session isn't linked to a journal entry.
  Future<void> _appendToJournalEntry({
    required String userText,
    required String assistantText,
  }) async {
    final entryId = widget.journalEntryId;
    final user = FirebaseAuth.instance.currentUser;
    if (entryId == null || user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journalEntries')
          .doc(entryId)
          .update({
            'followUpConversation': FieldValue.arrayUnion([
              {'role': 'user', 'text': userText},
              {'role': 'assistant', 'text': assistantText},
            ]),
          })
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // Non-critical — the conversation still shows in this session even
      // if persisting it to the journal entry fails.
    }
  }

  String _generateMockResponse(String input) {
    final lower = input.toLowerCase();

    if (lower.contains('bleed') || lower.contains('blood')) {
      return "For minor bleeding: apply firm, direct pressure with a clean "
          "cloth for at least 10 minutes, then clean and bandage the wound. "
          "If bleeding doesn't stop after 10-15 minutes, soaks through the "
          "bandage, or is from a deep wound, seek emergency care right away.";
    }
    if (lower.contains('swelling') ||
        lower.contains('swell') ||
        lower.contains('puss') ||
        lower.contains('pus')) {
      return "Some mild swelling can be normal in the first day or two. "
          "However, increasing swelling, pus, warmth, or redness spreading "
          "outward can be signs of infection. If you're seeing these signs, "
          "I'd recommend having it checked by a medical professional.";
    }
    if (lower.contains('burn')) {
      return "For minor burns: cool the area under running water for about "
          "10-20 minutes, don't apply ice directly, and cover loosely with "
          "a clean, non-stick bandage. Avoid butter or toothpaste — these "
          "can trap heat and worsen the burn. Seek care for burns larger "
          "than your palm, or on the face/hands/joints.";
    }
    if (lower.contains('fever') || lower.contains('temperature')) {
      return "A mild fever can sometimes accompany healing, but a "
          "persistent or high fever alongside a wound can be a sign of "
          "infection spreading. If your temperature is above 38°C (100.4°F) "
          "and not improving, please seek medical attention.";
    }
    if (lower.contains('pain') || lower.contains('hurt')) {
      return "Some discomfort during healing is expected, but pain that's "
          "getting worse instead of better — especially a few days in — "
          "can be a warning sign. Over-the-counter pain relief and keeping "
          "the area clean can help, but worsening pain warrants a check-up.";
    }
    if (lower.contains('animal') ||
        lower.contains('bite') ||
        lower.contains('dog') ||
        lower.contains('cat')) {
      return "Animal bites and scratches carry a risk of infection and, in "
          "some cases, rabies. Clean the wound thoroughly with soap and "
          "water, and it's important to see a medical professional as soon "
          "as possible — even minor-looking bites should be evaluated.";
    }
    if (lower.contains('how long') || lower.contains('heal')) {
      return "Healing time varies by wound type — minor cuts typically heal "
          "in about 1-2 weeks, while burns and skin issues can take longer. "
          "Keeping the area clean, protected, and watching for signs of "
          "infection are the best ways to support healing.";
    }

    final offTopicKeywords = [
      'weather',
      'movie',
      'sports',
      'joke',
      'recipe',
      'game',
    ];
    if (offTopicKeywords.any((k) => lower.contains(k))) {
      return "I'm here to help specifically with first aid and wound care "
          "questions, so I'm not able to help with that. Is there anything "
          "about your symptoms or recovery I can help with?";
    }

    return "Thanks for sharing that. I want to make sure I give you safe, "
        "accurate guidance — could you tell me a bit more about your "
        "symptoms or what's concerning you? And as a reminder, this chat "
        "is for general guidance only and isn't a substitute for "
        "professional medical care.";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
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
                        ChatStrings.of(context).title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Keeps the title centred.
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          // The reminder that this is general guidance only.
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFBE9E7),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ChatStrings.of(context).banner,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildTypingIndicator(theme);
                }
                return _buildBubble(theme, _messages[index]);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GuestUsageBadge(),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: _buildFollowUpInputBar(theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpInputBar(ThemeData theme) {
    final hasText = _inputController.text.trim().isNotEmpty;
    final upload = ChatUploadStrings.of(context);
    final canSend = hasText || _attachment != null;
    final attachment = _attachment;
    final bar = Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.add_photo_alternate_outlined,
            size: 30,
            color: theme.colorScheme.primary,
          ),
          tooltip: upload.addFile,
          onPressed: (_isTyping || _isUploading) ? null : _pickAttachment,
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3F4),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: ChatStrings.of(context).inputHint,
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          icon: const Icon(Icons.send_rounded, size: 22),
          tooltip: ChatStrings.of(context).send,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            fixedSize: const Size(48, 48),
          ),
          onPressed: (_isTyping || _isUploading || !canSend)
              ? null
              : _handleSend,
        ),
      ],
    );

    if (attachment == null) return bar;

    // Preview of the picked photo, with a remove button, above the input.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(attachment.path),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isUploading ? upload.uploading : upload.photoReady,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (_isUploading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: upload.removePhoto,
                  onPressed: () => setState(() => _attachment = null),
                ),
            ],
          ),
        ),
        bar,
      ],
    );
  }

  // The round picture beside a message: the Fine Aid mark for the assistant,
  // the person's profile photo (kept on this phone) for the user.
  Widget _avatar(ThemeData theme, {required bool isUser}) {
    final localPath = isUser ? LocalProfilePhoto().path : null;
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFE6E6E6),
      backgroundImage: localPath != null ? FileImage(File(localPath)) : null,
      child: localPath != null
          ? null
          : isUser
          ? Icon(Icons.person, color: Colors.grey.shade600)
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                'assets/images/FINE_AID_Logo_Icon.png',
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
    );
  }

  Widget _buildBubble(ThemeData theme, _ChatMessage message) {
    final urgent = !message.isUser && message.isUrgent;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.68,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: message.isUser
            ? const Color(0xFFFDEEEC)
            : urgent
            ? Colors.red.shade50
            : const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(20),
        border: urgent ? Border.all(color: Colors.red.shade300) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.imagePath != null)
            Padding(
              padding: EdgeInsets.only(bottom: message.text.isNotEmpty ? 8 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(message.imagePath!),
                  width: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (message.text.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (urgent) ...[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    (!message.isUser &&
                            AppLanguageScope.isTagalog(context) &&
                            message.tagalog != null)
                        ? message.tagalog!
                        : message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: urgent ? Colors.red.shade700 : Colors.black87,
                      fontWeight: urgent ? FontWeight.bold : null,
                    ),
                  ),
                ),
              ],
            ),
          if (!message.isUser && message.otcSuggestions.isNotEmpty)
            OtcSuggestionsBlock(suggestions: message.otcSuggestions),
          if (!message.isUser && message.showNearby)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: NearbyHealthcareButton(),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            _avatar(theme, isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            _avatar(theme, isUser: true),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _avatar(theme, isUser: false),
          const SizedBox(width: 12),
          SizedBox(
            width: 38,
            height: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                3,
                (i) => CircleAvatar(
                  radius: 5,
                  backgroundColor: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
