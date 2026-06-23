import 'package:flutter/material.dart';

class _Condition {
  final String title;
  final List<_Question> questions;
  final List<String> steps;
  final String warning;

  const _Condition({
    required this.title,
    required this.questions,
    required this.steps,
    required this.warning,
  });
}

class _Question {
  final String text;
  bool? answer;
  _Question({required this.text});
}

class FirstAidKitScreen extends StatefulWidget {
  const FirstAidKitScreen({super.key});

  @override
  State<FirstAidKitScreen> createState() => _FirstAidKitScreenState();
}

class _FirstAidKitScreenState extends State<FirstAidKitScreen> {
  int? _expandedIndex;
  int? _showingResultFor;

  final List<_Condition> _conditions = [
    _Condition(
      title: 'Laceration/Cuts',
      questions: [
        _Question(text: 'Was the injury caused by animal bite?'),
        _Question(text: 'Is the cut deep?'),
        _Question(text: 'Is the wound dirty or contaminated?'),
      ],
      steps: [
        'Wash hands.',
        'Use clean gauze or cloth for pressure.',
        'Stop the bleeding by applying gentle pressure.',
        'Clean with warm running water.',
        'Cover the wound with a bandage.',
      ],
      warning: 'Seek Medical Help or Consultation If Bleeding Doesn\'t Stop',
    ),
    _Condition(
      title: 'Minor Burns',
      questions: [
        _Question(text: 'Is the burn larger than your palm?'),
        _Question(text: 'Is the burn on the face, hands, or joints?'),
        _Question(text: 'Are there blisters forming?'),
      ],
      steps: [
        'Cool the burn under running water for 10-20 minutes.',
        'Do not apply ice directly to the burn.',
        'Remove jewelry near the burned area.',
        'Cover loosely with a clean, non-stick bandage.',
        'Do not burst any blisters.',
      ],
      warning: 'Seek Medical Help for Large, Deep, or Facial Burns',
    ),
    _Condition(
      title: 'Animal Bite/Scratch',
      questions: [
        _Question(text: 'Is the wound deep or bleeding heavily?'),
        _Question(text: 'Is the animal unknown or possibly rabid?'),
        _Question(text: 'Is there swelling or redness spreading?'),
      ],
      steps: [
        'Wash the wound thoroughly with soap and water for 5 minutes.',
        'Apply an antiseptic if available.',
        'Cover with a clean bandage.',
        'Seek medical attention immediately.',
        'Report the incident to local health authorities.',
      ],
      warning: 'Seek Immediate Medical Attention — Rabies Risk',
    ),
    _Condition(
      title: 'Abrasions/Scrape',
      questions: [
        _Question(text: 'Is the wound contaminated with dirt?'),
        _Question(text: 'Is there significant bleeding?'),
        _Question(text: 'Is the abrasion larger than your palm?'),
      ],
      steps: [
        'Rinse the scrape gently under clean running water.',
        'Remove any visible debris carefully.',
        'Apply antiseptic ointment if available.',
        'Cover with a sterile bandage or gauze.',
        'Change the dressing daily until healed.',
      ],
      warning: 'Seek Medical Help If Signs of Infection Develop',
    ),
  ];

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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'A pre-loaded library for basic guidance to first aid care. '
                  'No Wi-Fi or data required in an emergency.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'How to Use: Tap the arrow on any condition to expand details.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _conditions.length,
                itemBuilder: (context, index) {
                  final condition = _conditions[index];
                  final isExpanded = _expandedIndex == index;
                  final showingResult = _showingResultFor == index;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.primary),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            condition.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_right,
                            color: theme.colorScheme.primary,
                          ),
                          onTap: () => setState(() {
                            _expandedIndex = isExpanded ? null : index;
                            _showingResultFor = null;
                            for (final q in condition.questions) {
                              q.answer = null;
                            }
                          }),
                        ),
                        if (isExpanded)
                          showingResult
                              ? _buildResult(theme, condition, index)
                              : _buildQuestions(theme, condition, index),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestions(ThemeData theme, _Condition condition, int index) {
    final allAnswered = condition.questions.every((q) => q.answer != null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            ...condition.questions.map((question) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Text(
                      question.text,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _answerButton(
                          theme,
                          'Yes',
                          question.answer == true,
                          () => setState(() => question.answer = true),
                        ),
                        const SizedBox(width: 12),
                        _answerButton(
                          theme,
                          'No',
                          question.answer == false,
                          () => setState(() => question.answer = false),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Here\'s the first-aid you can follow.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: allAnswered
                      ? () => setState(() => _showingResultFor = index)
                      : null,
                  child: const Text('Proceed'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _answerButton(
    ThemeData theme,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.green : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildResult(ThemeData theme, _Condition condition, int index) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.healing,
                color: theme.colorScheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              condition.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please follow these care steps to help prevent your wound from getting infected.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...condition.steps.asMap().entries.map(
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.warning_amber_rounded, size: 18),
              label: Text(
                condition.warning,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() {
                _showingResultFor = null;
                for (final q in condition.questions) {
                  q.answer = null;
                }
              }),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
