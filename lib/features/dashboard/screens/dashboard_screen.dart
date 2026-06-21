import 'package:flutter/material.dart';
import '../../../services/firebase/auth_service.dart';
import '../../settings/screens/profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../journal/screens/journal_list_screen.dart';
import '../../camera/screens/ai_camera_screen.dart';

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
          onPressed: () {},
        ),

        IconButton(
          key: _profileKey,
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
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
            'Welcome!',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
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
          Text(
            'Healing tracker calendar coming soon',
            style: theme.textTheme.bodySmall,
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
    return Row(
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AiCameraScreen()),
              );
            },
          ),
        ),

        const SizedBox(width: 12),
        Expanded(
          child: _actionTile(
            theme,
            Icons.support_agent_outlined,
            'Help &\nSupport',
          ),
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
