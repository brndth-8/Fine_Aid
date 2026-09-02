import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../journal/screens/journal_list_screen.dart';
import '../../camera/screens/ai_camera_screen.dart';
import '../../settings/screens/help_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../settings/screens/guest_profile_gate_screen.dart';
import '../../settings/screens/profile_screen.dart';
import '../screens/notifications_screen.dart';
import '../first_aid_kit_screen.dart';
import '../../../services/connectivity_service.dart';
import 'textbook_viewer_screen.dart';

class _BookItem {
  final String title;
  final String imagePath;
  final String pdfPath;

  const _BookItem({
    required this.title,
    required this.imagePath,
    required this.pdfPath,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isOnline = true;
  DateTime _displayedMonth = DateTime.now();

  // Tour keys
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _actionTilesKey = GlobalKey();

  // Book carousel
  final PageController _bookController = PageController(viewportFraction: 0.55);
  int _currentBookPage = 0;

  final List<_BookItem> _books = const [
    _BookItem(
      title: 'First Aid Reference Guide',
      imagePath: 'assets/images/books/9db08e09-34bd-4553-b1ba-d1ae592627d4.jpg',
      pdfPath: 'assets/pdfs/SJA-First-Aid-Reference-Guide-English.pdf',
    ),
    _BookItem(
      title:
          'IFRC International First Aid, Resuscitation and Education Guidelines 2025',
      imagePath:
          'assets/images/books/6a929f4b-fb12-4ae3-be63-5af42a559d39 (1).jpg',
      pdfPath: 'assets/pdfs/E-AG-5.5-First-Aid-Vision-2030.pdf',
    ),
    _BookItem(
      title: 'Philippine Red Cross First Aid Support',
      imagePath:
          'assets/images/books/philippine_red_cross_first_aid_support.jpg',
      pdfPath: 'assets/pdfs/Philippine Red Cross First Aid Support.pdf',
    ),
    _BookItem(
      title: 'First Aid Pocket Guide',
      imagePath: 'assets/images/books/first_aid_pocket_guide.jpg',
      pdfPath: 'assets/pdfs/First Aid Pocket Guide.pdf',
    ),
    _BookItem(
      title: 'First Aid and CPR Manual',
      imagePath: 'assets/images/books/first_aid_and_CPR_manual.jpg',
      pdfPath: 'assets/pdfs/FA-CPR-AED-Part-Manual (1).pdf',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Check initial connectivity
    ConnectivityService().isOnline.then((online) {
      if (mounted) setState(() => _isOnline = online);
    });

    // Listen for connectivity changes
    ConnectivityService().onlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _bookController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null;

    return Scaffold(
      bottomNavigationBar: _buildBottomNav(theme),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/FINE_AID_Logo.png',
                    width: 70,
                    height: 50,
                  ),
                  const Spacer(),
                  // Notification bell
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
                  // Profile icon
                  IconButton(
                    key: _profileKey,
                    icon: const Icon(Icons.account_circle_outlined),
                    onPressed: () {
                      if (isGuest) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const GuestProfileGateScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  // Hamburger menu
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome banner
                    _buildWelcomeBanner(theme),
                    const SizedBox(height: 16),

                    // First Aid Textbook Guide
                    Text(
                      'First Aid Textbook Guide',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildBookCarousel(theme),
                    const SizedBox(height: 16),

                    // Offline: First Aid Health Kit card
                    if (!_isOnline) ...[
                      _buildFirstAidKitCard(theme),
                      const SizedBox(height: 16),
                    ],

                    // Calendar Dashboard
                    Text(
                      'Calendar Dashboard',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildCalendar(theme),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(ThemeData theme) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null;

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
              'Continue tracking and viewing guides '
              'without internet.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (isGuest) {
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
              'Welcome to Guest Mode',
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Register for full access to features '
              'with no limitation.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/registration'),
              child: Text(
                'Sign in and login your account. '
                'Register here',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
            'Welcome!',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Stay safe and ready with Fine Aid. '
            'Your guide for reliable first aid '
            'and tracking your recovery.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCarousel(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(
          theme.colorScheme.surfaceContainerHighest,
          Colors.black,
          0.15,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: PageView.builder(
              controller: _bookController,
              padEnds: false,
              itemCount: _books.length,
              onPageChanged: (i) => setState(() => _currentBookPage = i),
              itemBuilder: (context, index) {
                final book = _books[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _TextbookCard(
                    book: book,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TextbookViewerScreen(
                          title: book.title,
                          assetPdfPath: book.pdfPath,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_books.length, (index) {
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

  Widget _buildFirstAidKitCard(ThemeData theme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FirstAidKitScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
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
    );
  }

  Widget _buildCalendar(ThemeData theme) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: user != null
          ? FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('journalEntries')
                .snapshots()
          : const Stream.empty(),
      builder: (context, snapshot) {
        final markedDates = <DateTime>{};
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final ts = doc.data()['createdAt'] as Timestamp?;
            if (ts != null) {
              final date = ts.toDate();
              markedDates.add(DateTime(date.year, date.month, date.day));
            }
          }
        }
        return _buildCalendarWidget(theme, markedDates);
      },
    );
  }

  Widget _buildCalendarWidget(ThemeData theme, Set<DateTime> markedDates) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(
      _displayedMonth.year,
      _displayedMonth.month,
    );
    final firstWeekday =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday % 7;
    final isCurrentMonth =
        _displayedMonth.year == now.year && _displayedMonth.month == now.month;

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
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month - 1,
                    );
                  });
                },
              ),
              Text(
                '${_monthName(_displayedMonth.month)} '
                '${_displayedMonth.year}',
                style: theme.textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month + 1,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Day headers
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

          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return const SizedBox();
              }
              final day = index - firstWeekday + 1;
              final thisDate = DateTime(
                _displayedMonth.year,
                _displayedMonth.month,
                day,
              );
              final isToday = isCurrentMonth && day == now.day;
              final hasEntry = markedDates.contains(thisDate);

              return GestureDetector(
                onTap: hasEntry
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const JournalListScreen(),
                          ),
                        );
                      }
                    : null,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Today highlight
                      if (isToday)
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      // Day number
                      Text(
                        '$day',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isToday ? Colors.white : null,
                          fontWeight: isToday ? FontWeight.bold : null,
                        ),
                      ),
                      // Journal entry dot
                      if (hasEntry && !isToday)
                        Positioned(
                          bottom: 1,
                          child: Container(
                            width: 20,
                            height: 15,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),

                      // Today + entry: white dot
                      if (hasEntry && isToday)
                        Positioned(
                          bottom: 1,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(width: 6),
              Text(
                'Today',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    return Container(
      key: _actionTilesKey,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _bottomNavItem(
                  icon: Icons.menu_book_outlined,
                  label: 'Health\nJournal',
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
              Expanded(
                child: _bottomNavItem(
                  icon: Icons.center_focus_strong_outlined,
                  label: 'AI Vision\nCamera',
                  onTap: () {
                    if (!_isOnline) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: const Text('Your Currently Offline'),
                          content: const Text(
                            'AI Camera is disabled. '
                            'Check your connection or '
                            'use First Aid Health Kit.',
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Go Back'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AiCameraScreen(),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: _bottomNavItem(
                  icon: Icons.support_agent_outlined,
                  label: 'Help &\nSupport',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextbookCard extends StatelessWidget {
  final _BookItem book;
  final VoidCallback onTap;

  const _TextbookCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    book.imagePath,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      child: Icon(
                        Icons.menu_book_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
