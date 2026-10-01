import 'dart:async';
import 'dart:io';
import '../../../services/api/gemini_service.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'assessment_result_screen.dart';
import 'multi_injury_screen.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/image_compressor.dart';
import '../../dashboard/first_aid_kit_screen.dart';

class AiCameraScreen extends StatefulWidget {
  const AiCameraScreen({super.key});

  @override
  State<AiCameraScreen> createState() => _AiCameraScreenState();
}

class _AiCameraScreenState extends State<AiCameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  String? _errorMessage;

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
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera found on this device.');
        return;
      }
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _initializeControllerFuture = _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _errorMessage = 'Could not start camera: $e');
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleCapture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final online = await ConnectivityService().isOnline;
    if (!online) {
      if (!mounted) return;
      await _showOfflineDialog();
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final image = await _controller!.takePicture();
      if (!mounted) return;
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
                    'AI Vision Camera',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
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

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_controller == null || _initializeControllerFuture == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_controller!),
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
            ],
          ),
        );
      },
    );
  }
}
