import 'package:flutter/material.dart';
import '../../../core/text_scale_controller.dart';
import '../../../i18n/settings_strings.dart';

class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  // The last size the person accepted (the one the screen opened with, until
  // they choose another). Going back to it undoes a too-large choice.
  double _accepted = TextScaleController.instance.scale;

  /// After a size is chosen: past [TextScaleController.largeThreshold] a
  /// warning asks whether to keep it. Nothing is blocked: "Keep this size"
  /// leaves it as chosen, "Go back" returns to the size accepted before.
  Future<void> _sizeChosen(double value) async {
    if (!TextScaleController.isLarge(value) ||
        TextScaleController.isLarge(_accepted)) {
      _accepted = value;
      return;
    }
    final s = SettingsStrings.of(context);
    final keep = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.text_fields, size: 36),
        title: Text(s.textSizeWarnTitle, textAlign: TextAlign.center),
        content: Text(s.textSizeWarnBody),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.textSizeRevert),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.textSizeKeep),
          ),
        ],
      ),
    );
    if (keep == true) {
      _accepted = value;
    } else {
      await TextScaleController.instance.setScale(_accepted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(SettingsStrings.of(context).personalization),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        // Scrolls when the text is large, so nothing is cut off; the closing
        // note still sits at the bottom of a tall screen.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 38,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Adjust Text Size',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListenableBuilder(
                      listenable: TextScaleController.instance,
                      builder: (context, _) {
                        final scale = TextScaleController.instance.scale;
                        return Column(
                          children: [
                            Row(
                              children: [
                                Text('A', style: theme.textTheme.bodySmall),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor:
                                          theme.colorScheme.primary,
                                      inactiveTrackColor: const Color(
                                        0xFFFFD6D6,
                                      ),
                                      thumbColor: theme.colorScheme.primary,
                                      activeTickMarkColor: Colors.white,
                                      inactiveTickMarkColor: const Color(
                                        0xFFF0A0A0,
                                      ),
                                    ),
                                    child: Slider(
                                      value: scale,
                                      min: TextScaleController.min,
                                      max: TextScaleController.max,
                                      divisions: 8,
                                      label: '${(scale * 100).round()}%',
                                      onChanged: (value) => TextScaleController
                                          .instance
                                          .setScale(value),
                                      onChangeEnd: _sizeChosen,
                                    ),
                                  ),
                                ),
                                Text('A', style: theme.textTheme.headlineSmall),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7F7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Sample Text',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'The quick brown fox jumps over the lazy dog. '
                                    'Adjust to see the changes.\nABC',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const Spacer(),
                    Text(
                      'This applies across the whole app immediately and is '
                      'remembered next time you open Fine Aid.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
