import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../journal/screens/journal_list_screen.dart';
import '../../journal/screens/day_entries_screen.dart';
import '../../camera/screens/ai_camera_screen.dart';
import '../../settings/screens/help_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../settings/screens/guest_profile_gate_screen.dart';
import '../../settings/screens/profile_screen.dart';
import '../screens/notifications_screen.dart';
import '../first_aid_kit_screen.dart';
import '../../../i18n/tour_strings.dart';
import '../../../i18n/nav_strings.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../i18n/calendar_strings.dart';
import '../../../services/connectivity_service.dart';
import '../../../core/widgets/help_tour_launcher.dart';
import '../../../core/widgets/help_tour_overlay.dart';
import '../../../core/widgets/custom_bottom_nav_bar.dart';
import '../../../core/widgets/connectivity_badge.dart';
import '../../../services/notification_inbox_store.dart';
import 'textbook_viewer_screen.dart';
import '../../../services/firebase/textbook_service.dart';

class _BookItem {
  final String title;

  /// Bundled cover picture, or null for the generic book icon.
  final String? imagePath;

  /// Where the PDF is in Firebase Storage, eg `textbooks/Some Book.pdf`.
  final String storagePath;

  const _BookItem({
    required this.title,
    required this.imagePath,
    required this.storagePath,
  });
}

// Covers that ship with the app, by the PDF's file name. A book added in
// Firebase later has no bundled cover and shows the generic book icon.
const Map<String, String> _bundledCovers = {
  'SJA-First-Aid-Reference-Guide-English.pdf':
      'assets/images/books/9db08e09-34bd-4553-b1ba-d1ae592627d4.jpg',
  'E-AG-5.5-First-Aid-Vision-2030.pdf':
      'assets/images/books/6a929f4b-fb12-4ae3-be63-5af42a559d39 (1).jpg',
  'Philippine Red Cross First Aid Support.pdf':
      'assets/images/books/philippine_red_cross_first_aid_support.jpg',
  'First Aid Pocket Guide.pdf':
      'assets/images/books/first_aid_pocket_guide.jpg',
  'FA-CPR-AED-Part-Manual.pdf':
      'assets/images/books/first_aid_handbook_manual.jpg',
};

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isOnline = true;
  DateTime _displayedMonth = DateTime.now();
  int? _selectedNavIndex;

  // Bottom nav
  List<BottomNavItem> _navItems(NavStrings n) => [
    BottomNavItem(icon: Icons.menu_book_outlined, label: n.healthJournal),
    BottomNavItem(icon: Icons.crop_free, label: n.aiVisionCamera, badge: 'AI'),
    BottomNavItem(icon: Icons.support_agent_outlined, label: n.helpAndSupport),
  ];

  // Tour keys
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _settingsKey = GlobalKey();
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _actionTilesKey = GlobalKey();
  final GlobalKey _journalNavKey = GlobalKey();
  final GlobalKey _scannerNavKey = GlobalKey();
  final GlobalKey _helpNavKey = GlobalKey();
  final GlobalKey _bookCarouselKey = GlobalKey();

  bool _showTour = false;

  // Book carousel
  final PageController _bookController = PageController(viewportFraction: 0.75);
  int _currentBookPage = 1;

  // The built-in list: shown straight away and kept if Firebase can't be
  // reached. Replaced by the list in Firestore (`textbooks`) once it loads.
  List<_BookItem> _books = const [
    _BookItem(
      title: 'First Aid Reference Guide',
      imagePath: 'assets/images/books/9db08e09-34bd-4553-b1ba-d1ae592627d4.jpg',
      storagePath: 'textbooks/SJA-First-Aid-Reference-Guide-English.pdf',
    ),
    _BookItem(
      title:
          'IFRC International First Aid, Resuscitation and Education Guidelines 2025',
      imagePath:
          'assets/images/books/6a929f4b-fb12-4ae3-be63-5af42a559d39 (1).jpg',
      storagePath: 'textbooks/E-AG-5.5-First-Aid-Vision-2030.pdf',
    ),
    _BookItem(
      title: 'Philippine Red Cross First Aid Support',
      imagePath:
          'assets/images/books/philippine_red_cross_first_aid_support.jpg',
      storagePath: 'textbooks/Philippine Red Cross First Aid Support.pdf',
    ),
    _BookItem(
      title: 'First Aid Pocket Guide',
      imagePath: 'assets/images/books/first_aid_pocket_guide.jpg',
      storagePath: 'textbooks/First Aid Pocket Guide.pdf',
    ),
    _BookItem(
      title: 'First Aid Hand book Manual',
      imagePath: 'assets/images/books/first_aid_handbook_manual.jpg',
      storagePath: 'textbooks/FA-CPR-AED-Part-Manual.pdf',
    ),
  ];

  Future<void> _loadBooks() async {
    final list = await TextbookService.instance.fetchList();
    if (!mounted || list.isEmpty) return;
    setState(() {
      _books = [
        for (final b in list)
          _BookItem(
            title: b.title,
            imagePath: _bundledCovers[b.fileName],
            storagePath: b.storagePath,
          ),
      ];
    });
  }

  static bool _guestTourShownThisSession = false;

  @override
  void initState() {
    super.initState();
    _bookController.addListener(_onBookScroll);
    _loadBooks();

    // Check initial connectivity
    ConnectivityService().isOnline.then((online) {
      if (mounted) setState(() => _isOnline = online);
    });

    // Listen for connectivity changes
    ConnectivityService().onlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });

    HelpTourLauncher.instance.requestToken.addListener(_onTourRequested);
    _maybeAutoShowTour();
  }

  Future<void> _maybeAutoShowTour() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Guest session — show once per app run rather than persisting
      // anything, since guest state doesn't survive a restart anyway.
      if (!_guestTourShownThisSession) {
        _guestTourShownThisSession = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _showTour = true);
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.data()?['helpTourSeen'] == true) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'helpTourSeen': true},
      );

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _showTour = true);
        });
      }
    } catch (_) {
      // Non-critical — if this fails, the tour simply won't auto-show.
    }
  }

  void _onTourRequested() {
    if (mounted) setState(() => _showTour = true);
  }

  void _onBookScroll() {
    final page = _bookController.page;
    if (page == null) return;
    final rounded = page.round().clamp(0, _books.length - 1);
    if (rounded != _currentBookPage) {
      setState(() => _currentBookPage = rounded);
    }
  }

  List<HelpTourStep> _tourSteps(TourStrings t) => [
    HelpTourStep(
      title: t.steps[0].title,
      description: t.steps[0].description,
      icon: Icons.waving_hand_outlined,
    ),
    HelpTourStep(
      targetKey: _scannerNavKey,
      title: t.steps[1].title,
      description: t.steps[1].description,
      icon: Icons.center_focus_strong_outlined,
    ),
    HelpTourStep(
      targetKey: _journalNavKey,
      title: t.steps[2].title,
      description: t.steps[2].description,
      icon: Icons.menu_book_outlined,
    ),
    HelpTourStep(
      targetKey: _bookCarouselKey,
      title: t.steps[3].title,
      description: t.steps[3].description,
      icon: Icons.import_contacts_outlined,
    ),
    HelpTourStep(
      targetKey: _helpNavKey,
      title: t.steps[4].title,
      description: t.steps[4].description,
      icon: Icons.support_agent_outlined,
    ),
    HelpTourStep(
      targetKey: _profileKey,
      title: t.steps[5].title,
      description: t.steps[5].description,
      icon: Icons.account_circle_outlined,
    ),
    HelpTourStep(
      targetKey: _settingsKey,
      title: t.steps[6].title,
      description: t.steps[6].description,
      icon: Icons.settings,
    ),
  ];

  @override
  void dispose() {
    _bookController.dispose();
    HelpTourLauncher.instance.requestToken.removeListener(_onTourRequested);
    super.dispose();
  }

  void _handleNavTap(int index) {
    setState(() => _selectedNavIndex = index);
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const JournalListScreen()),
        );
        break;
      case 1:
        if (!_isOnline) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Your Currently Offline'),
              content: const Text(
                'AI Camera requires an internet connection. Check your '
                'connection and try again, or use the offline First Aid '
                'Health Kit instead.',
              ),
              actions: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FirstAidKitScreen(),
                      ),
                    );
                  },
                  child: const Text('First Aid Kit'),
                ),
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
          MaterialPageRoute(builder: (context) => const AiCameraScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HelpScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null;

    return Stack(
      children: [
        _buildScaffold(theme, isGuest),
        if (_showTour)
          HelpTourOverlay(
            steps: _tourSteps(TourStrings.of(context)),
            skipLabel: TourStrings.of(context).skipTour,
            backLabel: TourStrings.of(context).back,
            nextLabel: TourStrings.of(context).next,
            doneLabel: TourStrings.of(context).done,
            onFinished: () => setState(() => _showTour = false),
          ),
      ],
    );
  }

  Widget _buildScaffold(ThemeData theme, bool isGuest) {
    return Scaffold(
      bottomNavigationBar: CustomBottomNavBar(
        key: _actionTilesKey,
        items: _navItems(NavStrings.of(context)),
        itemKeys: [_journalNavKey, _scannerNavKey, _helpNavKey],
        selectedIndex: _selectedNavIndex,
        onItemTap: _handleNavTap,
      ),
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
                  const SizedBox(width: 8),
                  const ConnectivityBadge(),
                  const Spacer(),
                  // Notification bell
                  ListenableBuilder(
                    listenable: NotificationInboxStore.instance,
                    builder: (context, child) {
                      final unread =
                          NotificationInboxStore.instance.unreadCount;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          child!,
                          if (unread > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unread > 9 ? '9+' : '$unread',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                    child: IconButton(
                      iconSize: 30,
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
                  ),
                  // Profile icon
                  IconButton(
                    key: _profileKey,
                    iconSize: 30,
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
                  // Settings
                  IconButton(
                    key: _settingsKey,
                    iconSize: 30,
                    icon: const Icon(Icons.settings_outlined),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'First Aid Textbook Guide',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  _AllBooksScreen(books: _books),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View all',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
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
        padding: const EdgeInsets.fromLTRB(20, 20, 110, 20),
        decoration: _bannerDecoration(theme),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 110, 20),
      decoration: _bannerDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome!',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
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

  // The Welcome banner's background: the banner picture, kept to the right
  // so the first-aid kit stays visible whatever the banner's height.
  BoxDecoration _bannerDecoration(ThemeData theme) => BoxDecoration(
    color: theme.colorScheme.primary,
    borderRadius: BorderRadius.circular(20),
    image: const DecorationImage(
      image: AssetImage('assets/images/welcome_banner.png'),
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
    ),
  );

  Widget _buildBookCarousel(ThemeData theme) {
    return Container(
      key: _bookCarouselKey,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: PageView.builder(
              controller: _bookController,
              padEnds: false,
              itemCount: _books.length,
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
                          storagePath: book.storagePath,
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
                      : Colors.grey.shade500,
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
                    'First Aid Basic Guide - Free Access',
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

  // Opens the date picker and shows the month of the date chosen.
  Future<void> _jumpToDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context,
      initial: DateTime(_displayedMonth.year, _displayedMonth.month, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => _displayedMonth = DateTime(picked.year, picked.month));
    }
  }

  Widget _buildCalendarWidget(ThemeData theme, Set<DateTime> markedDates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final c = CalendarStrings.of(context);
    final daysInMonth = DateUtils.getDaysInMonth(
      _displayedMonth.year,
      _displayedMonth.month,
    );
    final firstWeekday =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday % 7;
    final isCurrentMonth =
        _displayedMonth.year == now.year && _displayedMonth.month == now.month;

    return GestureDetector(
      // Swipe left for the next month, right for the previous one.
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -200) {
          setState(() {
            _displayedMonth = DateTime(
              _displayedMonth.year,
              _displayedMonth.month + 1,
            );
          });
        }
        if (v > 200) {
          setState(() {
            _displayedMonth = DateTime(
              _displayedMonth.year,
              _displayedMonth.month - 1,
            );
          });
        }
      },
      child: Container(
        key: _calendarKey,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            // Month navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 30),
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month - 1,
                      );
                    });
                  },
                ),
                // Tap the month to jump straight to any date.
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _jumpToDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${c.months[_displayedMonth.month - 1]} '
                          '${_displayedMonth.year}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.black),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 30),
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
            if (!isCurrentMonth)
              TextButton(
                onPressed: () => setState(() {
                  _displayedMonth = DateTime(now.year, now.month);
                }),
                child: Text(c.jumpToToday),
              ),
            const SizedBox(height: 8),

            // Day headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < 7; i++)
                  SizedBox(
                    width: 32,
                    child: Text(
                      c.weekdays[i],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        // Weekends in maroon, the rest in black.
                        color: (i == 0 || i == 6)
                            ? theme.colorScheme.primary
                            : Colors.black,
                      ),
                    ),
                  ),
              ],
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
                final isWeekend =
                    thisDate.weekday == DateTime.saturday ||
                    thisDate.weekday == DateTime.sunday;

                return GestureDetector(
                  onTap: hasEntry
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  DayEntriesScreen(initialDate: thisDate),
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            // Days still to come are dimmed.
                            color: isToday
                                ? Colors.white
                                : (thisDate.isAfter(today)
                                      ? Colors.grey.shade500
                                      : (isWeekend
                                            ? theme.colorScheme.primary
                                            : null)),
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
                  c.today,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
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
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    book.imagePath ?? '',
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
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
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

/// "View all": every textbook as a two-column grid; tapping one opens it.
class _AllBooksScreen extends StatelessWidget {
  final List<_BookItem> books;

  const _AllBooksScreen({required this.books});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'First Aid Textbook Guide',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return _TextbookCard(
                      book: book,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TextbookViewerScreen(
                            title: book.title,
                            storagePath: book.storagePath,
                          ),
                        ),
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
}
