import 'package:flutter/material.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../services/connectivity_service.dart';
import '../../settings/screens/profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../journal/screens/journal_list_screen.dart';
import '../../camera/screens/ai_camera_screen.dart';
import '../../settings/screens/help_screen.dart';
import 'notifications_screen.dart';
import '../first_aid_kit_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../settings/screens/guest_profile_gate_screen.dart';

class _TourStep {
  final GlobalKey targetKey;
  final String message;

  _TourStep({required this.targetKey, required this.message});
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PageController _bookController = PageController();
  int _currentBookPage = 0;

  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _bookCarouselKey = GlobalKey();
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _actionTilesKey = GlobalKey();

  late List<_TourStep> _tourSteps;
  int _tourStepIndex = -1; // -1 means tour is not active
  bool _isOnline = true;

  final List<String> _bookTitles = const [
    'American Red Cross First Aid & Safety Handbook',
    'First Aid & CPR',
    'American Red Cross Textbook on Home Hygiene and Care of the Sick',
    'Wilderness First Aid',
    'Pediatric First Aid Guide',
  ];

  @override
  void initState() {
    super.initState();
    _tourSteps = [
      _TourStep(
        targetKey: _profileKey,
        message: 'This page is to view and edit profile information.',
      ),
      _TourStep(
        targetKey: _bookCarouselKey,
        message:
            'Browse trusted first aid references here, anytime, even offline.',
      ),
      _TourStep(
        targetKey: _calendarKey,
        message: 'Track your healing progress and recovery dates here.',
      ),
      _TourStep(
        targetKey: _actionTilesKey,
        message:
            'Quick access to your Health Journal, AI Camera, and Help & Support.',
      ),
    ];

    ConnectivityService().isOnline.then((online) {
      if (mounted) setState(() => _isOnline = online);
    });

    ConnectivityService().onlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args == true) {
        setState(() => _tourStepIndex = 0);
      }
    });
  }

  @override
  void dispose() {
    _bookController.dispose();
    super.dispose();
  }

  void _nextTourStep() {
    setState(() {
      if (_tourStepIndex < _tourSteps.length - 1) {
        _tourStepIndex++;
      } else {
        _tourStepIndex = -1;
      }
    });
  }

  void _skipTour() {
    setState(() => _tourStepIndex = -1);
  }

  void _replayTour() {
    setState(() => _tourStepIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(theme),
                  const SizedBox(height: 16),
                  _buildWelcomeBanner(theme),
                  const SizedBox(height: 24),
                  Text(
                    'First Aid Textbook Guide',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildBookCarousel(theme),
                  const SizedBox(height: 24),
                  Text('Calendar Dashboard', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _buildCalendarPlaceholder(theme),
                  const SizedBox(height: 24),
                  _buildActionTiles(theme),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (_tourStepIndex >= 0) _buildTourOverlay(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTourOverlay(ThemeData theme) {
    final step = _tourSteps[_tourStepIndex];
    final targetContext = step.targetKey.currentContext;

    Offset position = const Offset(40, 200);
    Size size = const Size(40, 40);

    if (targetContext != null) {
      final box = targetContext.findRenderObject() as RenderBox;
      position = box.localToGlobal(Offset.zero);
      size = box.size;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    const tooltipWidth = 260.0;
    const horizontalMargin = 16.0;

    double left = position.dx + size.width - tooltipWidth;
    if (left < horizontalMargin) left = horizontalMargin;
    if (left + tooltipWidth > screenWidth - horizontalMargin) {
      left = screenWidth - tooltipWidth - horizontalMargin;
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: _skipTour,
          child: Container(color: Colors.black.withValues(alpha: 0.5)),
        ),
        Positioned(
          left: left,
          top: position.dy + size.height + 8,
          child: Container(
            width: tooltipWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(step.message, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(onPressed: _skipTour, child: const Text('Skip')),
                    ElevatedButton(
                      onPressed: _nextTourStep,
                      child: Text(
                        _tourStepIndex == _tourSteps.length - 1
                            ? 'Done'
                            : 'Next',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Row(
      children: [
        Image.asset('assets/images/FINE_AID_Logo.png', width: 70, height: 40),
        const Spacer(),

        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
        ),

        IconButton(
          key: _profileKey,
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () {
            final isGuest = FirebaseAuth.instance.currentUser == null;
            if (isGuest) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GuestProfileGateScreen(),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            }
          },
        ),

        IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _showMenu(context),
        ),
      ],
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tour_outlined),
              title: const Text('Replay tour'),
              onTap: () {
                Navigator.pop(context);
                _replayTour();
              },
            ),

            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () async {
                Navigator.pop(context);
                await AuthService().signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(ThemeData theme) {
    final isGuest = FirebaseAuth.instance.currentUser == null;

    if (!_isOnline) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'You\'re currently offline',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Continue tracking and viewing guides without internet.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isGuest ? 'Welcome to Guest Mode' : 'Welcome!',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          if (isGuest) ...[
            Text(
              'Register for full access to features with no limitation.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/registration'),
              child: Text(
                'Sign in and login your account. Register here',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else
            Text(
              'Stay safe and ready with Fine Aid. Your guide for reliable '
              'first aid and tracking your recovery.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildBookCarousel(ThemeData theme) {
    return Container(
      key: _bookCarouselKey,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _bookController,
              itemCount: _bookTitles.length,
              onPageChanged: (i) => setState(() => _currentBookPage = i),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: Text(
                        _bookTitles[index],
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_bookTitles.length, (index) {
              final isActive = index == _currentBookPage;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarPlaceholder(ThemeData theme) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstWeekday = DateTime(now.year, now.month, 1).weekday % 7;

    return Container(
      key: _calendarKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${_monthName(now.month)} ${now.year}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                .map(
                  (d) => SizedBox(
                    width: 32,
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstWeekday) return const SizedBox();
              final day = index - firstWeekday + 1;
              final isToday = day == now.day;
              return Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: isToday
                      ? BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Center(
                    child: Text(
                      '$day',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isToday ? Colors.white : null,
                        fontWeight: isToday ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Widget _buildActionTiles(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isOnline) ...[
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FirstAidKitScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.medical_services_outlined,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'First Aid Health Kit',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'First Aid Basic Guide — Free Access',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ],
        Row(
          key: _actionTilesKey,
          children: [
            Expanded(
              child: _actionTile(
                theme,
                Icons.menu_book_outlined,
                'Health\nJournal',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JournalListScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionTile(
                theme,
                Icons.center_focus_strong_outlined,
                'AI Vision\nCamera',
                onTap: () {
                  if (!_isOnline) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text('You\'re Currently Offline'),
                        content: const Text(
                          'AI Camera is disabled. Check your connection or use First Aid Health Kit.',
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Go Back'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AiCameraScreen(),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionTile(
                theme,
                Icons.support_agent_outlined,
                'Help &\nSupport',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionTile(
    ThemeData theme,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ?? () {},
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
