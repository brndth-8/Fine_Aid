import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/first_aid_step_images.dart';
import '../../i18n/step_image_strings.dart';

/// The optional picture beside a First Aid step. Draws NOTHING — no space, no
/// placeholder, no broken-image icon — when the step has no kind, when its
/// file isn't in the app, or when the image fails to load. When there is a
/// picture it is a fixed-size rounded square (scaled to the screen width,
/// never stretched), with a quiet placeholder until it appears and a spoken
/// description in the app's language.
class FirstAidStepImage extends StatefulWidget {
  /// A value from [firstAidStepImageKeys], or null for "no image".
  final String? imageKey;

  const FirstAidStepImage({super.key, required this.imageKey});

  @override
  State<FirstAidStepImage> createState() => _FirstAidStepImageState();
}

class _FirstAidStepImageState extends State<FirstAidStepImage> {
  // Which asset paths are registered in each bundle — read once per bundle.
  static final Expando<Future<Set<String>>> _manifests = Expando();
  static final Map<String, bool> _known = {};

  bool _failed = false;

  static Future<bool> _exists(AssetBundle bundle, String path) async {
    try {
      final assets = await (_manifests[bundle] ??=
          AssetManifest.loadFromAssetBundle(
            bundle,
          ).then((m) => m.listAssets().toSet()));
      return _known[path] = assets.contains(path);
    } catch (_) {
      return _known[path] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.imageKey;
    if (key == null || _failed) return const SizedBox.shrink();

    final path = firstAidStepImagePath(key);
    final bundle = DefaultAssetBundle.of(context);
    final size = (MediaQuery.sizeOf(context).width * 0.17).clamp(52.0, 76.0);

    return FutureBuilder<bool>(
      future: _exists(bundle, path),
      initialData: _known[path],
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Semantics(
            image: true,
            label: StepImageStrings.of(context).describe(key),
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: size,
                height: size,
                child: Image.asset(
                  path,
                  bundle: bundle,
                  fit: BoxFit.contain,
                  // The files are large; decode them at display size.
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  frameBuilder: (context, child, frame, wasSynchronous) {
                    if (wasSynchronous || frame != null) return child;
                    return ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    );
                  },
                  errorBuilder: (context, error, stack) {
                    // A broken file hides the whole slot, gap included.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_failed) setState(() => _failed = true);
                    });
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
