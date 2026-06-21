import 'package:flutter/material.dart';

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}

class ChatbotScreen extends StatefulWidget {
  final String? initialContext; // e.g. "Burns" classification from journal

  const ChatbotScreen({super.key, this.initialContext});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    final greeting = widget.initialContext != null
        ? "Hi! I see you're asking about a ${widget.initialContext} entry. "
              "How can I help — are you noticing any new symptoms, or do you "
              "have a question about care steps?"
        : "Hi! I'm the Fine Aid Assistant. I can help answer questions about "
              "first aid, wound care, and what to expect during healing. "
              "What's on your mind?";
    _messages.add(_ChatMessage(text: greeting, isUser: false));
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
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });
    _inputController.clear();
    _scrollToBottom();

    //Real version will call the Gemini API, with the same "medical responses only"

    await Future.delayed(const Duration(milliseconds: 700));
    final response = _generateMockResponse(text);

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(text: response, isUser: false));
      _isTyping = false;
    });
    _scrollToBottom();
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

    // Politely redirect anything that isn't first-aid related.
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
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: const Icon(
                      Icons.health_and_safety,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Fine Aid Assistant',
                    style: theme.textTheme.titleMedium,
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
              padding: const EdgeInsets.all(16),
              child: Container(
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
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: theme.colorScheme.primary),
                      onPressed: _handleSend,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(ThemeData theme, _ChatMessage message) {
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
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: message.isUser ? Colors.white : null,
          ),
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
