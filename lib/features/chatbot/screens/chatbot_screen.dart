import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/api/gemini_service.dart';
import '../../../services/firebase/storage_service.dart';
import '../../../services/image_compressor.dart';
import '../../camera/screens/ai_camera_screen.dart';
import '../../../i18n/chat_upload_strings.dart';
import '../../../core/photo_permission.dart';
import '../../../core/nearby_intent.dart';
import '../../../core/widgets/nearby_healthcare_sheet.dart';
import '../../../i18n/nearby_strings.dart';
import '../../../services/firebase/first_aid_content_service.dart';
import '../../../services/voice_input_service.dart';
import '../../../services/otc_filter_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/guest_usage_service.dart';
import '../../../core/widgets/voice_message_bubble.dart';
import '../../../core/widgets/otc_suggestions_block.dart';
import '../../../core/widgets/guest_gate_dialogs.dart';
import '../../../core/widgets/guest_usage_badge.dart';
import '../../../core/network_error.dart';
import '../../../core/scope_check.dart';

class _ChatMessage {
  final String text;
  final String? tagalog;
  final bool isUser;
  final bool isUrgent;
  final List<OtcSuggestion> otcSuggestions;
  // Set only for a voice message — the recorded clip's local file path, so
  // it can be replayed as a chat bubble. `text` is always the transcript
  // either way.
  final String? audioPath;
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
    this.audioPath,
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
  bool _showTagalog = false;

  // A photo the user picked but hasn't sent yet (preview + remove), and
  // whether it's being uploaded to Firebase Storage right now.
  XFile? _attachment;
  bool _isUploading = false;

  final VoiceInputService _voiceInput = VoiceInputService();
  bool _isRecording = false;
  Duration _recordingElapsed = Duration.zero;
  double _recordingLevel = 0;
  Timer? _recordingTimer;
  StreamSubscription<double>? _amplitudeSubscription;

  @override
  void initState() {
    super.initState();
    final greeting = widget.initialContext != null
        ? "Hi! I see you're asking about a ${widget.initialContext} entry. "
              "How can I help. Are you noticing any new symptoms, or do you "
              "have a question about care steps?"
        : "Hi! I'm the Fine Aid Assistant. I can help answer questions about "
              "first aid, wound care, and what to expect during healing. "
              "What's on your mind?";
    _messages.add(_ChatMessage(text: greeting, isUser: false));
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
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _voiceInput.dispose();
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

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startVoiceRecording() async {
    if (_isTyping || _isRecording) return;

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

    await _sendMessage(result.transcript, audioPath: result.audioPath);
  }

  Future<void> _sendMessage(String text, {String? audioPath}) async {
    if (text.isEmpty || _isTyping) return;

    // Scope check first — free, no network, no quota — so it works
    // offline and never counts against a guest's daily limit.
    if (looksObviouslyOutOfScope(text)) {
      setState(() {
        _messages.add(
          _ChatMessage(text: text, isUser: true, audioPath: audioPath),
        );
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
      _messages.add(
        _ChatMessage(text: text, isUser: true, audioPath: audioPath),
      );
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
                      'Fine Aid Assistant',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showTagalog = !_showTagalog),
                    icon: const Icon(Icons.translate, size: 16),
                    label: Text(
                      _showTagalog ? 'English' : 'Tagalog',
                      style: theme.textTheme.bodySmall,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'This assistant provides general first aid guidance only and is '
                'not a substitute for professional medical advice.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: GuestUsageBadge(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildFollowUpInputBar(theme),
            ),
          ],
        ),
      ),
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

    final hasText = _inputController.text.trim().isNotEmpty;
    final upload = ChatUploadStrings.of(context);
    final canSend = hasText || _attachment != null;
    final attachment = _attachment;
    final bar = Container(
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
                controller: _inputController,
                decoration: const InputDecoration(
                  hintText: 'Describe your concern...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.add_photo_alternate_outlined,
              color: theme.colorScheme.primary,
            ),
            tooltip: upload.addFile,
            onPressed: (_isTyping || _isUploading) ? null : _pickAttachment,
          ),
          IconButton(
            icon: Icon(Icons.mic, color: theme.colorScheme.primary),
            tooltip: 'Record a follow-up question',
            onPressed: (_isTyping || _isUploading)
                ? null
                : _startVoiceRecording,
          ),
          IconButton(
            icon: Icon(Icons.send, color: theme.colorScheme.primary),
            tooltip: 'Send',
            onPressed: (_isTyping || _isUploading || !canSend)
                ? null
                : _handleSend,
          ),
        ],
      ),
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

  Widget _buildBubble(ThemeData theme, _ChatMessage message) {
    final urgent = !message.isUser && message.isUrgent;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser
              ? theme.colorScheme.primary
              : urgent
              ? Colors.red.shade50
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: urgent ? Border.all(color: Colors.red.shade300) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.audioPath != null) ...[
              VoiceMessageBubble(
                audioPath: message.audioPath!,
                isUser: message.isUser,
              ),
              const SizedBox(height: 6),
            ],
            if (message.imagePath != null)
              Padding(
                padding: EdgeInsets.only(
                  bottom: message.text.isNotEmpty ? 8 : 0,
                ),
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
                              _showTagalog &&
                              message.tagalog != null)
                          ? message.tagalog!
                          : message.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: message.isUser
                            ? Colors.white
                            : urgent
                            ? Colors.red.shade700
                            : null,
                        fontWeight: urgent ? FontWeight.bold : null,
                        fontStyle: message.audioPath != null
                            ? FontStyle.italic
                            : null,
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
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: SizedBox(
          width: 24,
          height: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              3,
              (i) => CircleAvatar(
                radius: 3,
                backgroundColor: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
