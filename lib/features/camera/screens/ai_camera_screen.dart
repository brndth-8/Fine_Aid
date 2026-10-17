import 'dart:async';
import 'dart:io';
import '../../../services/api/gemini_service.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../i18n/settings_strings.dart';
import 'assessment_result_screen.dart';
import 'multi_injury_screen.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/image_compressor.dart';
import '../../dashboard/first_aid_kit_screen.dart';

class AiCameraScreen extends StatefulWidget {
  /// When true this is just a camera: it returns the captured photo's path
  /// (via Navigator.pop) instead of running the AI scan — used where the app
  /// only needs a photo, eg attaching an image to a Health Journal entry.
  final bool captureOnly;

  const AiCameraScreen({super.key, this.captureOnly = false});

  @override
  State<AiCameraScreen> createState() => _AiCameraScreenState();
}

class _AiCameraScreenState extends State<AiCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _cameraReady = false;
  List<CameraDescription> _cameras = [];
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  bool _switchingCamera = false;
  String? _errorMessage;

  // Camera permission was refused (or is blocked): show a message with a
  // link to the phone's settings instead of a blank/generic error.
  bool _cameraDenied = false;
  bool _cameraPermanentlyDenied = false;

  // Flashlight, zoom and tap-to-focus state.
  bool _torchOn = false;
  bool _torchUnsupported = false;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  double _zoomAtGestureStart = 1;
  Offset? _focusPoint;
  Timer? _focusRingTimer;

  // The photo just taken, shown in place of the live preview while it's
  // being scanned so the user can see it was captured.
  String? _capturedImagePath;

  // Simulated scan progress — the wound pre-check can't report real
  // progress, so this eases toward 90% while waiting and jumps to 100%
  // once the result is back.
  double _scanProgress = 0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCamera();
  }

  // Coming back from the phone's settings after allowing the camera: start
  // it automatically instead of making the user tap "Try Again".
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _cameraDenied) {
      _setupCamera();
    }
  }

  Future<void> _setupCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() => _errorMessage = 'No camera found on this device.');
        }
        return;
      }
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      await _startCamera(backCamera);
    } on CameraException catch (e) {
      await _handleCameraError(e);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not start camera: $e');
    }
  }

  /// (Re)starts the camera on [description] — used at launch and when
  /// flipping between the front and back cameras.
  Future<void> _startCamera(CameraDescription description) async {
    final previous = _controller;
    if (mounted) {
      setState(() {
        _controller = null;
        _cameraReady = false;
        _cameraDenied = false;
        _errorMessage = null;
        _torchOn = false;
      });
      // Let the preview of the old camera leave the tree before it's
      // disposed, so it never paints a disposed controller.
      await WidgetsBinding.instance.endOfFrame;
    }
    await previous?.dispose();

    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      // Auto-focus and the zoom range aren't supported on every device, so
      // each is best-effort and never blocks the camera from opening.
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      var minZoom = 1.0;
      var maxZoom = 1.0;
      try {
        minZoom = await controller.getMinZoomLevel();
        maxZoom = await controller.getMaxZoomLevel();
      } catch (_) {}

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _zoom = minZoom;
        _cameraReady = true;
      });
    } on CameraException catch (e) {
      await controller.dispose();
      await _handleCameraError(e);
    }
  }

  Future<void> _handleCameraError(CameraException e) async {
    const denied = {
      'CameraAccessDenied',
      'CameraAccessDeniedWithoutPrompt',
      'CameraAccessRestricted',
    };
    if (!mounted) return;
    if (denied.contains(e.code)) {
      final status = await Permission.camera.status;
      if (!mounted) return;
      setState(() {
        _cameraDenied = true;
        // "Without prompt" / restricted / permanently denied: the system
        // won't ask again, so the only way back is the phone's settings.
        _cameraPermanentlyDenied =
            status.isPermanentlyDenied ||
            status.isRestricted ||
            e.code != 'CameraAccessDenied';
      });
    } else {
      setState(
        () => _errorMessage =
            'Could not start camera: ${e.description ?? e.code}',
      );
    }
  }

  CameraLensDirection? get _lens => _controller?.description.lensDirection;

  /// Switches between the front and back camera.
  Future<void> _flipCamera() async {
    if (_switchingCamera || _isCapturing || _isAnalyzing) return;
    final target = _lens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final next = _cameras.where((c) => c.lensDirection == target);
    if (next.isEmpty) return;

    setState(() => _switchingCamera = true);
    try {
      await _startCamera(next.first);
    } finally {
      if (mounted) setState(() => _switchingCamera = false);
    }
  }

  /// Turns the flashlight (torch) on/off. If the camera has none, the
  /// button is hidden instead of leaving a control that does nothing.
  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    final turnOn = !_torchOn;
    try {
      await controller.setFlashMode(turnOn ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchOn = turnOn);
    } on CameraException {
      if (!mounted) return;
      setState(() {
        _torchUnsupported = true;
        _torchOn = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flashlight is not available on this camera.'),
        ),
      );
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtGestureStart = _zoom;
  }

  /// Pinch-to-zoom within the camera's own zoom range.
  void _onScaleUpdate(ScaleUpdateDetails details) {
    final controller = _controller;
    if (controller == null || _maxZoom - _minZoom < 0.01) return;
    final zoom = (_zoomAtGestureStart * details.scale).clamp(
      _minZoom,
      _maxZoom,
    );
    if ((zoom - _zoom).abs() < 0.02) return;
    setState(() => _zoom = zoom);
    unawaited(controller.setZoomLevel(zoom).catchError((_) {}));
  }

  /// Tap-to-focus (and exposure) at the tapped point.
  Future<void> _focusAt(Offset position, Size previewSize) async {
    final controller = _controller;
    if (controller == null || previewSize.isEmpty) return;
    final point = Offset(
      (position.dx / previewSize.width).clamp(0.0, 1.0),
      (position.dy / previewSize.height).clamp(0.0, 1.0),
    );
    setState(() => _focusPoint = position);
    _focusRingTimer?.cancel();
    _focusRingTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focusPoint = null);
    });
    try {
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
    } catch (_) {
      // Not every camera supports a focus point; the ring is just feedback.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    _focusRingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleCapture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    // The offline check only matters for the AI scan; a plain photo capture
    // needs no connection.
    if (!widget.captureOnly) {
      final online = await ConnectivityService().isOnline;
      if (!online) {
        if (!mounted) return;
        await _showOfflineDialog();
        return;
      }
    }

    setState(() => _isCapturing = true);
    try {
      final image = await _controller!.takePicture();
      if (!mounted) return;
      if (widget.captureOnly) {
        final path = await compressImageFile(image.path);
        if (!mounted) return;
        Navigator.pop(context, path);
        return;
      }
      setState(() => _capturedImagePath = image.path);
      // Shrink the photo before it's analyzed: full-size camera photos are
      // several MB, which made the AI calls slow and prone to timing out.
      // Detection boxes and the selection screen then all use this same
      // compressed copy (the original is returned if compression fails).
      final compressedPath = await compressImageFile(image.path);
      if (!mounted) return;
      await _processImage(compressedPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not capture image. Please try again.'),
        ),
      );
    } finally {
      _stopScanProgress();
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isAnalyzing = false;
          _capturedImagePath = null;
        });
      }
    }
  }

  void _startScanProgress() {
    _progressTimer?.cancel();
    _scanProgress = 0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() => _scanProgress += (0.9 - _scanProgress) * 0.06);
    });
  }

  void _stopScanProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  String get _scanStageLabel {
    if (_scanProgress >= 1) return 'Scan complete';
    if (_scanProgress < 0.3) return 'Checking image quality...';
    if (_scanProgress < 0.6) return 'Detecting wound...';
    return 'Verifying wound...';
  }

  /// Runs wound pre-check on [imagePath] and routes to the right next
  /// screen, or shows an appropriate state instead of proceeding — this is
  /// the "Free Pass Filter". It has three outcomes: PASS (proceed to
  /// classification/recommendations), FAIL (blurry, no wound, or a mark
  /// that looks artificial — eg, a pen line), or UNCERTAIN (can't tell
  /// either way, so don't force a category). Classification, first aid
  /// steps, and OTC suggestions only ever happen after a PASS here.
  Future<void> _processImage(String imagePath) async {
    setState(() => _isAnalyzing = true);
    _startScanProgress();

    final detection = await GeminiService().detectWounds(imagePath);

    _stopScanProgress();
    if (!mounted) return;
    // Show the bar reaching 100% before moving on.
    setState(() => _scanProgress = 1);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    if (detection.isBlurry) {
      await _showBlurryDialog();
      return;
    }

    switch (detection.freePassResult) {
      case FreePassResult.fail:
        final artificial =
            detection.artificialMarkLikelihood == ArtificialMarkLikelihood.yes;
        await _showNoWoundDialog(artificialMarkSuspected: artificial);
        return;
      case FreePassResult.uncertain:
        await _showLowConfidenceDialog();
        return;
      case FreePassResult.pass:
        break;
    }

    if (!mounted) return;

    // Multiple wounds detected
    if (detection.woundCount > 1) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MultiInjuryScreen(
            imagePath: imagePath,
            woundDescriptions: detection.woundDescriptions,
            woundBoxes: detection.woundBoxes,
          ),
        ),
      );
      return;
    }

    // Single wound — automatically selected, go straight to assessment
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssessmentResultScreen(
          imagePath: imagePath,
          woundHints: detection.woundDescriptions,
        ),
      ),
    );
  }

  void _goToOfflineKit() {
    Navigator.pop(context); // close the dialog
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const FirstAidKitScreen()),
    );
  }

  Future<void> _showOfflineDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('No Internet Connection'),
        content: const Text(
          'AI wound analysis requires an internet connection. Please check '
          'your connection and try again, or use the offline First Aid '
          'Health Kit instead.',
        ),
        actions: [
          OutlinedButton(
            onPressed: _goToOfflineKit,
            child: const Text('Offline First Aid Kit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBlurryDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Image Too Blurry'),
        content: const Text(
          'This photo is too blurry to assess safely. Please ensure the '
          'area is well-lit and your camera is in focus, hold steady, and '
          'try again.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retake Photo'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNoWoundDialog({
    bool artificialMarkSuspected = false,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('No Wound Detected'),
        content: Text(
          artificialMarkSuspected
              ? 'Fine Aid could not confirm a real wound or skin condition '
                    'in this image — the mark shown may not be an actual '
                    'injury (eg, a drawing, marking, or something else on '
                    'the skin). Please retake a photo of a real wound or '
                    'skin issue if you have one.'
              : 'Fine Aid could not detect a wound or skin condition in '
                    'this image. Please retake a clearer photo of the '
                    'affected area.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retake Photo'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLowConfidenceDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unable to Confidently Analyze'),
        content: const Text(
          'This image is too unclear or ambiguous for Fine Aid to '
          'confidently identify a wound. To avoid misleading guidance, '
          'we won\'t proceed with this photo. Please retake a clearer '
          'photo, or use the offline First Aid Health Kit.',
        ),
        actions: [
          OutlinedButton(
            onPressed: _goToOfflineKit,
            child: const Text('Offline Kit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retake'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    widget.captureOnly ? 'Take Photo' : 'AI Vision Camera',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // The AI-assessment disclaimer isn't relevant to a plain photo.
            if (!widget.captureOnly)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'MEDICAL DISCLAIMER',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This is only for initial assessment and not a diagnostic. '
                        'Seek professional help.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildCameraPreview(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _isAnalyzing
                  ? _buildScanProgress(theme)
                  : Center(
                      child: GestureDetector(
                        onTap: _isCapturing ? null : _handleCapture,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          // Dimmed (not a spinner) for the split second
                          // the shutter takes before the photo appears.
                          child: Icon(
                            Icons.camera_alt,
                            color: _isCapturing ? Colors.white38 : Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanProgress(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: _scanProgress),
          duration: const Duration(milliseconds: 250),
          builder: (context, value, _) => Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$_scanStageLabel  ${(value * 100).round()}%',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    final captured = _capturedImagePath;
    if (captured != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(captured), fit: BoxFit.cover),
            if (_isAnalyzing)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Photo captured. Scanning...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (_cameraDenied) return _buildPermissionDenied();

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !_cameraReady) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final showTorch =
        controller.description.lensDirection == CameraLensDirection.back &&
        !_torchUnsupported;
    final canFlip = _cameras.map((c) => c.lensDirection).toSet().length > 1;
    final zoomed = _maxZoom - _minZoom > 0.01 && _zoom - _minZoom > 0.05;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onTapUp: (details) => _focusAt(details.localPosition, size),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (_focusPoint != null)
                  Positioned(
                    left: _focusPoint!.dx - 28,
                    top: _focusPoint!.dy - 28,
                    child: IgnorePointer(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 2),
                        ),
                      ),
                    ),
                  ),
                if (zoomed)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_zoom.toStringAsFixed(1)}x',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(
                    children: [
                      if (canFlip)
                        _cameraControl(
                          icon: Icons.flip_camera_android_outlined,
                          tooltip: 'Switch camera',
                          onPressed: _switchingCamera ? null : _flipCamera,
                        ),
                      if (showTorch) ...[
                        const SizedBox(height: 8),
                        _cameraControl(
                          icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                          tooltip: _torchOn
                              ? 'Turn flashlight off'
                              : 'Turn flashlight on',
                          onPressed: _toggleTorch,
                          active: _torchOn,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cameraControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool active = false,
  }) {
    return Material(
      color: active ? Colors.amber : Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: active ? Colors.black : Colors.white),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  /// Shown when camera access was refused: a clear message plus a way to
  /// fix it (the phone's settings), instead of a blank or generic error.
  Widget _buildPermissionDenied() {
    final s = CameraPermissionStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              s.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _cameraPermanentlyDenied ? s.blockedMessage : s.askMessage,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: openAppSettings,
              icon: const Icon(Icons.settings),
              label: Text(s.openSettings),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _setupCamera,
              child: Text(
                s.tryAgain,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
