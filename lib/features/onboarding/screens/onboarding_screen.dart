import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firebase/auth_service.dart';

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _pageOffset = 0;
  bool _isLoading = false;

  late final AnimationController _entranceController;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      icon: Icons.camera_alt_outlined,
      title: 'AI Wound Scanning',
      description:
          'Point your camera at a wound or skin issue and let our '
          'AI analyze it to give you instant first aid guidance.',
    ),
    _OnboardingPageData(
      icon: Icons.menu_book_outlined,
      title: 'First Aid Textbook Guide',
      description:
          'Browse a trusted library of first aid references, '
          'always available even when you are offline.',
    ),
    _OnboardingPageData(
      icon: Icons.book_outlined,
      title: 'Health Journal',
      description:
          'Track your healing progress over time, with reminders '
          'and auto-referrals if a wound needs professional care.',
    ),
    _OnboardingPageData(
      icon: Icons.notifications_outlined,
      title: 'Stay Notified',
      description:
          'Get gentle reminders to check on your wounds and '
          'updates on new first aid content.',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    _entranceController.forward();

    _pageController.addListener(() {
      setState(() {
        _pageOffset = _pageController.page ?? _currentPage.toDouble();
      });
    });
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await AuthService().markOnboardingComplete(user.uid);
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            FadeTransition(
              opacity: _logoFade,
              child: SlideTransition(
                position: _logoSlide,
                child: Center(
                  child: Image.asset(
                    'assets/images/FINE_AID_Logo.png',
                    width: 160,
                    height: 160,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _isLoading ? null : _finishOnboarding,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  final delta = (_pageOffset - index).clamp(-1.0, 1.0);
                  final scale = 1 - (delta.abs() * 0.15);
                  final opacity = 1 - delta.abs();
                  final verticalOffset = delta * 40;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, verticalOffset),
                        child: Transform.scale(
                          scale: scale,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.7, end: 1.0),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.elasticOut,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: child,
                                  );
                                },
                                child: Icon(
                                  page.icon,
                                  size: 96,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                page.title,
                                style: theme.textTheme.headlineSmall,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                page.description,
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextPage,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: Text(
                            isLastPage ? 'Get Started' : 'Next',
                            key: ValueKey(isLastPage),
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
}
