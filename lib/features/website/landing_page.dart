/// Fine Aid public landing page — everything for the site at `/` lives in
/// this one file. Jump between parts by searching for the `####` banners;
/// each section inside SECTIONS starts with a `// 2. HERO`-style header.
///
/// Images: assets/web/ (see assets/web/README.md).
/// Contact details: site_config.dart.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/link.dart';

import 'site_config.dart';

// ######################################################################
// PAGE — scaffold, sticky nav, mobile menu
// ######################################################################

enum LandingSection { download, about, experts, contact }

/// Public single-page site served at `/`.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scroll = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _keys = {for (final s in LandingSection.values) s: GlobalKey()};
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final scrolled = _scroll.offset > 8;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double _navHeight(BuildContext context) =>
      Breakpoints.isMobile(context) ? 72 : 84;

  void _scrollTo(LandingSection section) {
    _scaffoldKey.currentState?.closeEndDrawer();
    final box =
        _keys[section]!.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final target = (_scroll.offset + top - _navHeight(context)).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final navHeight = _navHeight(context);
    final mobile = Breakpoints.isMobile(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      endDrawer: mobile ? _MobileMenu(onSelect: _scrollTo) : null,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: navHeight),
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeroSection(
                    minHeight: (MediaQuery.sizeOf(context).height - navHeight)
                        .clamp(0, double.infinity),
                    onCta: () => _scrollTo(LandingSection.download),
                  ),
                  DownloadSection(key: _keys[LandingSection.download]),
                  AboutSection(key: _keys[LandingSection.about]),
                  ExpertsSection(key: _keys[LandingSection.experts]),
                  const BrandStatementSection(),
                  LandingFooter(
                    key: _keys[LandingSection.contact],
                    onNavigate: _scrollTo,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: navHeight,
            child: _NavBar(
              elevated: _scrolled,
              mobile: mobile,
              onSelect: _scrollTo,
              onLogoTap: () => _scroll.animateTo(
                0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutCubic,
              ),
              onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.elevated,
    required this.mobile,
    required this.onSelect,
    required this.onLogoTap,
    required this.onMenu,
  });

  final bool elevated;
  final bool mobile;
  final ValueChanged<LandingSection> onSelect;
  final VoidCallback onLogoTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 480;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          if (elevated)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ContentWidth(
        child: Row(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onLogoTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedLogo(width: mobile ? 78 : 92),
                    if (!narrow)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Your Smart First Aid Assistant',
                          style: LandingText.nav(color: LandingColors.red800)
                              .copyWith(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (mobile)
              IconButton(
                tooltip: 'Open menu',
                onPressed: onMenu,
                icon: const Icon(Icons.menu, color: LandingColors.ink),
              )
            else ...[
              _NavLink('About', () => onSelect(LandingSection.about)),
              const SizedBox(width: 32),
              _NavLink('Experts', () => onSelect(LandingSection.experts)),
              const SizedBox(width: 32),
              _NavLink('Contact Us', () => onSelect(LandingSection.contact)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Underlined text link; a red underline grows in from the left on hover.
class _NavLink extends StatefulWidget {
  const _NavLink(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          // Stack sizes to the text; the underline is positioned beneath it.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  widget.label,
                  style: LandingText.nav(
                    color: _hover ? LandingColors.red800 : LandingColors.ink,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 1,
                height: 1,
                child: ColoredBox(color: LandingColors.ink),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 2,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: _hover ? 1 : 0),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  builder: (_, scaleX, child) => Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.diagonal3Values(scaleX, 1, 1),
                    child: child,
                  ),
                  child: const ColoredBox(color: LandingColors.red600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileMenu extends StatelessWidget {
  const _MobileMenu({required this.onSelect});

  final ValueChanged<LandingSection> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, LandingSection section) => ListTile(
      title: Text(label, style: LandingText.nav()),
      onTap: () => onSelect(section),
    );

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: AnimatedLogo(width: 110),
            ),
            item('About', LandingSection.about),
            item('Experts', LandingSection.experts),
            item('Contact Us', LandingSection.contact),
          ],
        ),
      ),
    );
  }
}

// ######################################################################
// SECTIONS — hero, download, about, experts, brand statement, footer
// ######################################################################

// Website images in assets/web/ (see assets/web/README.md). Any file that is
// still missing is rendered as a soft gradient placeholder.
class _Img {
  static const hero =
      'assets/web/hero.jpg'; // hands applying a bandage outdoors
  static const download = 'assets/web/download-bg.jpg'; // first aid supplies
  static const about = 'assets/web/about-lifestyle.jpg'; // antiseptic, outdoors
  static const expert1 = 'assets/web/expert-1.jpg'; // Galderma, Makati
  static const expert2 = 'assets/web/expert-2.jpg'; // advisory session, SJDM
  static const footer = 'assets/web/footer.jpg'; // hands with bandage/gloves
  static const qr = 'assets/web/qr.png'; // app download QR code
  static const worldMap = 'assets/web/world-map.png'; // faint world map
}

const _heroCopy =
    'First aid is more than just knowing how to put on a bandage. '
    'It is about having the capable confidence to step up.';

/// Full-bleed photo with a dark overlay behind centered white text.
class _PhotoBanner extends StatelessWidget {
  const _PhotoBanner({
    required this.asset,
    required this.child,
    this.minHeight = 0,
    this.padding = const EdgeInsets.symmetric(vertical: 110),
  });

  final String asset;
  final Widget child;
  final double minHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AssetOr(
              asset,
              placeholder: const PhotoPlaceholder(
                colors: [Color(0xFF3A2323), Color(0xFF1C1414)],
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    // Light touch: the supplied hero/download photos are
                    // already darkened for legibility.
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: ContentWidth(child: Reveal(child: child)),
          ),
        ],
      ),
    );
  }
}

class _LeadText extends StatelessWidget {
  const _LeadText();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Text(
        _heroCopy,
        textAlign: TextAlign.center,
        style: LandingText.body(
          color: Colors.white.withValues(alpha: 0.9),
          size: Breakpoints.isMobile(context) ? 16 : 18,
        ),
      ),
    );
  }
}

// ============================================================
// 2. HERO
// ============================================================
class HeroSection extends StatelessWidget {
  const HeroSection({super.key, required this.minHeight, required this.onCta});

  final double minHeight;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return _PhotoBanner(
      asset: _Img.hero,
      minHeight: minHeight,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Text(
            'BE THE HELP\nUNTIL HELP ARRIVES',
            textAlign: TextAlign.center,
            style: LandingText.display((width * 0.06).clamp(34, 74)).copyWith(
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _LeadText(),
          const SizedBox(height: 34),
          RedButton(label: 'Get yours now', onPressed: onCta),
        ],
      ),
    );
  }
}

// ============================================================
// 3. DOWNLOAD
// ============================================================
class DownloadSection extends StatelessWidget {
  const DownloadSection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return _PhotoBanner(
      asset: _Img.download,
      child: Column(
        children: [
          Text(
            'DOWNLOAD FINE AID',
            textAlign: TextAlign.center,
            style: LandingText.display((width * 0.05).clamp(30, 58)),
          ),
          const SizedBox(height: 22),
          const _LeadText(),
          const SizedBox(height: 34),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: SizedBox.square(
              dimension: 180,
              child: AssetOr(
                _Img.qr,
                fit: BoxFit.contain,
                placeholder: const _QrPlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'SCAN HERE',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 3.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCFCFCF), width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        'QR CODE',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          color: const Color(0xFFB5B5B5),
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ============================================================
// 4. ABOUT
// ============================================================
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  static const _p1 =
      'Fine Aid is an application integrating AI (Artificial Intelligence) '
      'that allows you to capture images of wounds, minor injuries, and skin '
      'issues to provide evidence-based first aid guidance, cross-referenced '
      'with verified protocols and recommendations from licensed medical '
      'professionals.';
  static const _p2 =
      'This includes the Monthly Index of Medical Specialties (MIMS) '
      'Philippines, the World Health Organization (WHO), and other local '
      'medical organizations — ensuring you avoid harmful home remedies and '
      'the risks of online myths.';

  @override
  Widget build(BuildContext context) {
    final mobile = Breakpoints.isMobile(context);
    final tablet = Breakpoints.isTablet(context);
    final width = MediaQuery.sizeOf(context).width;

    final heading = Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ABOUT', style: LandingText.sectionTitle(context)),
          const SizedBox(height: 6),
          Text(
            'YOUR SMART FIRST AID ASSISTANT',
            style: LandingText.sectionSub(color: LandingColors.red800),
          ),
        ],
      ),
    );
    const photo = AssetOr(
      _Img.about,
      placeholder: PhotoPlaceholder(label: 'About lifestyle photo'),
    );
    final panel = _AboutPanel(
      children: [
        Text(_p1, style: LandingText.body(color: LandingColors.ink)),
        const SizedBox(height: 16),
        Text(_p2, style: LandingText.body(color: LandingColors.ink)),
      ],
    );

    if (mobile) {
      return ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ContentWidth(child: heading),
              const SizedBox(height: 28),
              Reveal(
                child: Stack(
                  children: [
                    const Positioned.fill(child: photo),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
                      child: panel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Reveal(
                delay: const Duration(milliseconds: 120),
                child: Center(
                  child: FeatureCarousel(width: width < 400 ? 210 : 240),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Desktop / tablet: photo fills the right side; the device card and a
    // translucent text panel sit across it.
    final cardWidth = tablet ? 200.0 : 240.0;
    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: width * 0.55,
            child: photo,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 72),
            child: ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Reveal(
                        delay: const Duration(milliseconds: 120),
                        child: FeatureCarousel(width: cardWidth),
                      ),
                      Expanded(
                        child: Reveal(
                          delay: const Duration(milliseconds: 200),
                          child: panel,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted white text panel with the round logo badge on its corner.
class _AboutPanel extends StatelessWidget {
  const _AboutPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final mobile = Breakpoints.isMobile(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            mobile ? 22 : 40,
            mobile ? 30 : 36,
            mobile ? 22 : 36,
            mobile ? 26 : 36,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.horizontal(
              right: const Radius.circular(4),
              left: Radius.circular(mobile ? 4 : 0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
        Positioned(
          left: mobile ? 16 : -14,
          top: -14,
          child: Container(
            width: 30,
            height: 30,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: LandingColors.red800, width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ],
            ),
            child: Image.asset('assets/images/FINE_AID_Logo_Icon.png'),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 5. EXPERTS
// ============================================================
class _Expert {
  const _Expert(this.name, this.role);
  final String name;
  final String role;
}

const _experts = [
  _Expert('Dr. Deanne Asdala', 'Medical Affairs Manager'),
  _Expert('Mr. Samuel Evan Pacamparra,', 'RPh, Regulatory Affairs Manager'),
  _Expert('Dr. Anthony Morallas', 'Physician (Anesthesiology)'),
];

const _consultationParagraphs = [
  'On March 10, 2026, our team conducted an expert review and consultation '
      'with Dr. Deanne Asdala, Medical Affairs Manager, and Mr. Samuel Evan '
      'Pacamparra, RPh, Regulatory Affairs Manager from Galderma Philippines '
      'located at Guadalupe Viejo, Makati City.',
  'This consultative process continued on March 11, 2026, during an expert '
      'advisory session with Dr. Anthony Morallas, MD, a specialist physician '
      'in Anesthesiology, held at Dear Joe Cafe in Aspen, San Jose Del Monte, '
      'Bulacan.',
  'This engagement ensured that our medical safety frameworks align with '
      'high professional benchmarks and current healthcare standards.',
];

class ExpertsSection extends StatelessWidget {
  const ExpertsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = Breakpoints.isMobile(context);

    Widget photo(String asset, String semantic) => AspectRatio(
      aspectRatio: 1.82,
      child: Semantics(
        image: true,
        label: semantic,
        child: AssetOr(asset, placeholder: const PhotoPlaceholder()),
      ),
    );
    final photos = [
      photo(
        _Img.expert1,
        'Consultation with Galderma Philippines, Makati City',
      ),
      photo(_Img.expert2, 'Expert advisory session in San Jose Del Monte'),
    ];

    return ColoredBox(
      color: LandingColors.maroon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: ContentWidth(
              child: Reveal(
                child: Column(
                  children: [
                    Text(
                      'EXPERTS',
                      textAlign: TextAlign.center,
                      style: LandingText.sectionTitle(
                        context,
                        color: Colors.white,
                      ).copyWith(fontSize: mobile ? 34 : 44),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'BACKED BY CREDENTIALS. BUILT FOR SAFETY',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: mobile ? 13 : 16,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Edge-to-edge consultation photos
          if (mobile)
            ...photos
          else
            Row(
              children: [
                Expanded(child: photos[0]),
                Expanded(child: photos[1]),
              ],
            ),
          // Credentials + consultation details
          Padding(
            padding: EdgeInsets.symmetric(vertical: mobile ? 48 : 64),
            child: ContentWidth(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Reveal(
                        child: Text(
                          'Our protocols are developed in close alignment with '
                          'medical standards and industry regulations to '
                          'ensure reliability.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            fontSize: mobile ? 17 : 21,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _CredentialRow(mobile: mobile),
                      const SizedBox(height: 32),
                      for (final p in _consultationParagraphs)
                        Reveal(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              p,
                              style: LandingText.body(
                                color: Colors.white.withValues(alpha: 0.95),
                                size: mobile ? 15 : 17,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({required this.mobile});

  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (var i = 0; i < _experts.length; i++)
        Reveal(
          delay: Duration(milliseconds: mobile ? 0 : 80 * i),
          child: _CredentialCard(expert: _experts[i]),
        ),
    ];
    if (mobile) {
      return Column(
        children: [
          for (final card in cards)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: card),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 22),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

class _CredentialCard extends StatefulWidget {
  const _CredentialCard({required this.expert});

  final _Expert expert;

  @override
  State<_CredentialCard> createState() => _CredentialCardState();
}

class _CredentialCardState extends State<_CredentialCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(
      fontSize: 14.5,
      height: 1.45,
      color: LandingColors.ink,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _hover ? LandingColors.mauve : LandingColors.credentialCard,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hover ? 0.3 : 0.15),
              blurRadius: _hover ? 16 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${widget.expert.name}\n',
                style: style.copyWith(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: widget.expert.role),
            ],
          ),
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }
}

// ============================================================
// 6. BRAND STATEMENT
// ============================================================
class BrandStatementSection extends StatelessWidget {
  const BrandStatementSection({super.key});

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).width < 480;
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: AssetOr(
              _Img.worldMap,
              fit: BoxFit.contain,
              // Placeholder: soft dotted field fading out toward the edges.
              placeholder: ShaderMask(
                shaderCallback: (rect) => const RadialGradient(
                  radius: 0.75,
                  colors: [Colors.black, Colors.transparent],
                  stops: [0.35, 1],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: const CustomPaint(painter: _DotGridPainter()),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: small ? 90 : 130),
          child: ContentWidth(
            child: Column(
              children: [
                AnimatedLogo(
                  width: small ? 200 : 260,
                  trigger: LogoTrigger.scroll,
                ),
                const SizedBox(height: 14),
                Reveal(
                  child: Text(
                    '“Awareness to first aid can make a real difference.”',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: small ? 17 : 22,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: LandingColors.red900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = LandingColors.mapPink;
    const gap = 14.0;
    for (var y = gap / 2; y < size.height; y += gap) {
      for (var x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// 7. FOOTER
// ============================================================
class LandingFooter extends StatelessWidget {
  const LandingFooter({super.key, required this.onNavigate});

  final ValueChanged<LandingSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    final mobile = Breakpoints.isMobile(context);

    // Photo fades into the dark footer, as in the mockup.
    Widget photo({required bool fadeDown}) => Stack(
      fit: StackFit.expand,
      children: [
        const AssetOr(
          _Img.footer,
          placeholder: PhotoPlaceholder(
            colors: [Color(0xFF6B6B70), Color(0xFF2A2A2E)],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                LandingColors.footer.withValues(alpha: 0),
                LandingColors.footer.withValues(alpha: fadeDown ? 1 : 0.55),
              ],
              stops: const [0.35, 1],
            ),
          ),
        ),
      ],
    );

    final align = mobile ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final info = Column(
      crossAxisAlignment: align,
      children: [
        const AnimatedLogo(
          width: 130,
          trigger: LogoTrigger.scroll,
          asset: AnimatedLogo.lightAsset,
        ),
        Text(
          'Your Smart First Aid Assistant',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 26),
        _ContactRow(
          icon: Icons.location_on,
          center: mobile,
          child: Text(
            SiteConfig.address,
            textAlign: mobile ? TextAlign.center : TextAlign.start,
            style: _footerText,
          ),
        ),
        _ContactRow(
          icon: Icons.phone,
          center: mobile,
          child: _FooterLink(SiteConfig.phoneDisplay, uri: SiteConfig.phoneUri),
        ),
        _ContactRow(
          icon: Icons.send,
          center: mobile,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              _FooterLink(SiteConfig.email, uri: SiteConfig.emailUri),
              const _CopyEmailButton(),
            ],
          ),
        ),
        SizedBox(height: mobile ? 28 : 44),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '© 2026 '),
              TextSpan(
                text: 'Fine Aid',
                style: _footerText.copyWith(
                  color: LandingColors.red600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '. All rights reserved'),
            ],
          ),
          style: _footerText,
        ),
      ],
    );

    final menu = Column(
      crossAxisAlignment: align,
      children: [
        Text(
          'Main Menu',
          style: GoogleFonts.montserrat(
            color: LandingColors.red600,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 14),
        _FooterLink('About', onTap: () => onNavigate(LandingSection.about)),
        const SizedBox(height: 10),
        _FooterLink(
          'Validity',
          onTap: () => onNavigate(LandingSection.experts),
        ),
        const SizedBox(height: 10),
        _FooterLink(
          'Contact Us',
          onTap: () => onNavigate(LandingSection.contact),
        ),
      ],
    );

    if (mobile) {
      return ColoredBox(
        color: LandingColors.footer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 200, child: photo(fadeDown: true)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
              child: Column(children: [info, const SizedBox(height: 36), menu]),
            ),
          ],
        ),
      );
    }

    // Desktop / tablet: photo column on the left, sized to the text columns.
    return ColoredBox(
      color: LandingColors.footer,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final photoWidth = constraints.maxWidth * 0.3;
          return Stack(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 340),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(photoWidth + 48, 48, 48, 48),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: info),
                      const SizedBox(width: 32),
                      Expanded(flex: 2, child: menu),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: photoWidth,
                child: photo(fadeDown: false),
              ),
            ],
          );
        },
      ),
    );
  }
}

final _footerText = GoogleFonts.inter(
  color: Colors.white,
  fontSize: 14,
  height: 1.5,
);

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.child,
    this.center = false,
  });

  final IconData icon;
  final Widget child;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: center
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// Footer text link. With [uri] it renders a real `<a href>` on the web
/// (reliable for mailto:/tel:, and supports right-click → copy link);
/// otherwise [onTap] runs in-page navigation.
class _FooterLink extends StatefulWidget {
  const _FooterLink(this.label, {this.onTap, this.uri})
    : assert((onTap == null) != (uri == null));

  final String label;
  final VoidCallback? onTap;
  final Uri? uri;

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hover = false;

  Widget _text(VoidCallback? onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          widget.label,
          style: _footerText.copyWith(
            color: _hover ? LandingColors.red600 : Colors.white,
            decoration: _hover ? TextDecoration.underline : null,
            decorationColor: LandingColors.red600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uri = widget.uri;
    if (uri == null) {
      return Semantics(link: true, child: _text(widget.onTap));
    }
    return Link(
      uri: uri,
      target: LinkTarget.self,
      builder: (context, followLink) => _text(followLink),
    );
  }
}

/// Copies the contact email — a fallback for visitors with no email app set up.
class _CopyEmailButton extends StatelessWidget {
  const _CopyEmailButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Copy email address',
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      color: Colors.white70,
      hoverColor: Colors.white12,
      icon: const Icon(Icons.copy_rounded),
      onPressed: () async {
        await Clipboard.setData(const ClipboardData(text: SiteConfig.email));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email address copied'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }
}

// ######################################################################
// THEME — colors, breakpoints, text styles, shared widgets
// ######################################################################

class LandingColors {
  LandingColors._();

  static const red900 = Color(0xFF6E0F0F);
  static const red800 = Color(0xFF8B1A1A);
  static const red600 = Color(0xFFC41E1E);
  static const mauve = Color(0xFFF3E3E5);
  static const mauveEdge = Color(0xFFE6C9CD);
  static const ink = Color(0xFF1A1A1A);
  static const body = Color(0xFF4A4A4A);
  static const muted = Color(0xFF8A8A8A);
  static const offWhite = Color(0xFFFAF8F8);
  static const dark = Color(0xFF141111);

  // From the approved mockup
  static const maroon = Color(0xFF5E0E0E); // experts banner + credentials
  static const credentialCard = Color(0xFFD9BCC0);
  static const footer = Color(0xFF1E1E21);
  static const mapPink = Color(0xFFE9C9CC);
}

/// Width breakpoints shared by every section.
class Breakpoints {
  Breakpoints._();

  static const double mobile = 820;
  static const double tablet = 1024;
  static const double maxContent = 1180;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tablet;
}

class LandingText {
  LandingText._();

  static TextStyle display(double size, {Color color = Colors.white}) =>
      GoogleFonts.montserrat(
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1.05,
        color: color,
      );

  static TextStyle sectionTitle(BuildContext context, {Color? color}) =>
      GoogleFonts.montserrat(
        fontSize: Breakpoints.isMobile(context) ? 40 : 56,
        fontWeight: FontWeight.w900,
        height: 1,
        color: color ?? LandingColors.ink,
      );

  static TextStyle sectionSub({Color color = LandingColors.red600}) =>
      GoogleFonts.montserrat(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: color,
      );

  static TextStyle body({Color color = LandingColors.body, double size = 16}) =>
      GoogleFonts.inter(fontSize: size, height: 1.65, color: color);

  static TextStyle nav({Color color = LandingColors.ink}) =>
      GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      );
}

/// Centers content and caps it at the site's max width.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gutter = MediaQuery.sizeOf(context).width < 480 ? 16.0 : 24.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.maxContent),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
  }
}

class RedButton extends StatefulWidget {
  const RedButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<RedButton> createState() => _RedButtonState();
}

class _RedButtonState extends State<RedButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedSlide(
        offset: Offset(0, _hover ? -0.05 : 0),
        duration: const Duration(milliseconds: 200),
        child: FilledButton(
          onPressed: widget.onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _hover
                ? LandingColors.red800
                : LandingColors.red600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            elevation: _hover ? 10 : 6,
            shadowColor: LandingColors.red600.withValues(alpha: 0.5),
            textStyle: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          child: Text(widget.label.toUpperCase()),
        ),
      ),
    );
  }
}

/// Shows an image asset, or [placeholder] until that asset is supplied.
/// Expects tight constraints from its parent (Positioned.fill, SizedBox, …).
class AssetOr extends StatelessWidget {
  const AssetOr(
    this.asset, {
    super.key,
    required this.placeholder,
    this.fit = BoxFit.cover,
  });

  final String asset;
  final Widget placeholder;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, fit: fit, errorBuilder: (_, _, _) => placeholder);
  }
}

/// Soft gradient + label used where a placeholder photo is still missing.
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({
    super.key,
    this.label,
    this.colors = const [Color(0xFFEFE2E3), Color(0xFFD9BFC2)],
  });

  final String? label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: label == null
          ? const SizedBox.expand()
          : Center(
              child: Text(
                label!.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: LandingColors.red900.withValues(alpha: 0.45),
                ),
              ),
            ),
    );
  }
}

// ######################################################################
// ANIMATION — scroll reveal
// ######################################################################

/// Reports when its child enters or leaves the viewport of the enclosing
/// [Scrollable]. [threshold] is the fraction of the viewport height the
/// child's top must scroll past before it counts as visible.
class ViewportVisibility extends StatefulWidget {
  const ViewportVisibility({
    super.key,
    required this.onChanged,
    required this.child,
    this.threshold = 0.1,
  });

  final ValueChanged<bool> onChanged;
  final Widget child;
  final double threshold;

  @override
  State<ViewportVisibility> createState() => _ViewportVisibilityState();
}

class _ViewportVisibilityState extends State<ViewportVisibility> {
  ScrollPosition? _position;
  bool? _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_check);
      _position = position?..addListener(_check);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final top = box.localToGlobal(Offset.zero).dy;
    final visible =
        top < viewportHeight * (1 - widget.threshold) &&
        top + box.size.height > 0;
    if (visible != _visible) {
      _visible = visible;
      widget.onChanged(visible);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Fades and slides its child up the first time it scrolls into view.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  bool _shown = false;

  void _onVisible(bool visible) {
    if (!visible || _shown) return;
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    const duration = Duration(milliseconds: 800);
    const curve = Cubic(.22, .61, .36, 1);
    return ViewportVisibility(
      onChanged: _onVisible,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: duration,
        curve: curve,
        child: AnimatedSlide(
          offset: _shown ? Offset.zero : const Offset(0, 0.06),
          duration: duration,
          curve: curve,
          child: widget.child,
        ),
      ),
    );
  }
}

// ######################################################################
// ANIMATION — logo
// ######################################################################

/// When the logo's entrance animation plays.
enum LogoTrigger {
  /// Once, as the page first renders (nav bar).
  load,

  /// Every time the logo scrolls into view (brand statement, footer).
  scroll,
}

/// Fine Aid logo with the brand motion spec:
///  * entrance: scale 90% → 100% + fade, 0.6s ease-out
///  * hover: scale to 105%, 0.25s
///  * heartbeat: subtle double-pulse loop, 1.8s
///
/// PLACEHOLDER: LOGO — assets/images/FINE_AID_Logo.png. The logo is a single
/// raster, so the heartbeat pulses the whole mark; with a vector logo, wrap
/// only the red cross in the heartbeat [ScaleTransition].
class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({
    super.key,
    required this.width,
    this.trigger = LogoTrigger.load,
    this.asset = defaultAsset,
  });

  static const defaultAsset = 'assets/images/FINE_AID_Logo.png';

  /// Light variant (white "AID" + bandage) for dark backgrounds.
  static const lightAsset = 'assets/web/logo-light.png';

  final String asset;

  final double width;
  final LogoTrigger trigger;

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final AnimationController _heartbeat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  late final Animation<double> _entranceCurve = CurvedAnimation(
    parent: _entrance,
    curve: Curves.easeOut,
  );
  late final Animation<double> _pulse = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.035), weight: 15),
    TweenSequenceItem(tween: Tween(begin: 1.035, end: 1), weight: 15),
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.025), weight: 15),
    TweenSequenceItem(tween: Tween(begin: 1.025, end: 1), weight: 15),
    TweenSequenceItem(tween: ConstantTween(1), weight: 40),
  ]).animate(CurvedAnimation(parent: _heartbeat, curve: Curves.easeInOut));

  bool _hover = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _entrance.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_reduceMotion) {
        _heartbeat.repeat();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _entrance.value = 1;
      _heartbeat.stop();
    } else if (widget.trigger == LogoTrigger.load && _entrance.isDismissed) {
      _entrance.forward();
    }
  }

  void _onVisibility(bool visible) {
    if (_reduceMotion) return;
    if (visible) {
      _entrance.forward(from: 0);
    } else {
      _heartbeat.stop();
      _heartbeat.value = 0;
      _entrance.value = 0;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _heartbeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget logo = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.05 : 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: FadeTransition(
          opacity: _entranceCurve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(_entranceCurve),
            child: ScaleTransition(
              scale: _pulse,
              alignment: const Alignment(-0.4, 0.2),
              child: Image.asset(
                widget.asset,
                width: widget.width,
                semanticLabel: 'Fine Aid',
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.trigger == LogoTrigger.scroll) {
      logo = ViewportVisibility(
        threshold: 0.15,
        onChanged: _onVisibility,
        child: logo,
      );
    }
    return logo;
  }
}

// ######################################################################
// FEATURE CAROUSEL
// ######################################################################

class FeatureSlide {
  const FeatureSlide({
    required this.asset,
    required this.title,
    required this.caption,
    required this.icon,
  });

  /// Phone screenshot (≈9:19). If the file is missing, a mock screen built
  /// from [title], [caption] and [icon] is shown instead.
  final String asset;
  final String title;
  final String caption;
  final IconData icon;
}

/// Add more slides (up to 6) by dropping screen-N.jpg into assets/web/.
const featureSlides = [
  FeatureSlide(
    asset: 'assets/web/screen-1.jpg',
    title: 'AI Vision Camera',
    caption: 'Scan wounds and minor injuries',
    icon: Icons.document_scanner_outlined,
  ),
  FeatureSlide(
    asset: 'assets/web/screen-2.jpg',
    title: 'First Aid Dashboard',
    caption: 'Guides, reference books and your calendar',
    icon: Icons.medical_services_outlined,
  ),
  FeatureSlide(
    asset: 'assets/web/screen-4.jpg',
    title: 'Health Profile',
    caption: 'Conditions that change how you should respond',
    icon: Icons.health_and_safety_outlined,
  ),
  FeatureSlide(
    asset: 'assets/web/screen-5.jpg',
    title: 'Health Journal',
    caption: 'A self-monitoring guide for your recovery',
    icon: Icons.menu_book_outlined,
  ),
  FeatureSlide(
    asset: 'assets/web/screen-3.jpg',
    title: 'Journal Entry',
    caption: 'Log injuries and get healing reminders',
    icon: Icons.edit_note_outlined,
  ),
];

/// Auto-rotating app screenshots inside a maroon device card. Advances every
/// [interval]; pauses on hover (desktop) or tap (touch); swipe, the hover
/// arrows, or the dots navigate.
class FeatureCarousel extends StatefulWidget {
  const FeatureCarousel({
    super.key,
    this.slides = featureSlides,
    this.width = 240,
    this.interval = const Duration(milliseconds: 4500),
  });

  final List<FeatureSlide> slides;
  final double width;
  final Duration interval;

  @override
  State<FeatureCarousel> createState() => _FeatureCarouselState();
}

class _FeatureCarouselState extends State<FeatureCarousel> {
  int _index = 0;
  int _direction = 1;
  Timer? _timer;
  bool _hover = false;
  bool _tapPaused = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    if (_reduceMotion || _hover || _tapPaused) return;
    _timer = Timer.periodic(widget.interval, (_) => _go(_index + 1));
  }

  void _go(int next, {bool manual = false}) {
    final count = widget.slides.length;
    setState(() {
      _direction = next >= _index ? 1 : -1;
      _index = (next + count) % count;
    });
    if (manual) _restart();
  }

  void _setHover(bool hover) {
    setState(() => _hover = hover);
    _restart();
  }

  void _toggleTapPause() {
    setState(() => _tapPaused = !_tapPaused);
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth.clamp(160.0, widget.width)
            : widget.width;
        return _buildCard(width);
      },
    );
  }

  Widget _buildCard(double width) {
    const pad = 10.0;
    final screenWidth = width - pad * 2;
    return Semantics(
      label:
          'Fine Aid features, slide ${_index + 1} of ${widget.slides.length}',
      child: MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(pad, pad, pad, 0),
          decoration: BoxDecoration(
            color: LandingColors.red900,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: LandingColors.red900.withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: screenWidth,
                height: screenWidth * 19 / 9,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _toggleTapPause,
                        onHorizontalDragEnd: (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v.abs() < 150) return;
                          _go(v < 0 ? _index + 1 : _index - 1, manual: true);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: ColoredBox(
                            color: Colors.white,
                            child: _slides(),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      top: 0,
                      bottom: 0,
                      child: _Arrow(
                        visible: _hover,
                        icon: Icons.chevron_left,
                        tooltip: 'Previous slide',
                        onTap: () => _go(_index - 1, manual: true),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 0,
                      bottom: 0,
                      child: _Arrow(
                        visible: _hover,
                        icon: Icons.chevron_right,
                        tooltip: 'Next slide',
                        onTap: () => _go(_index + 1, manual: true),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 34, child: Center(child: _dots())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slides() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: const Cubic(.22, .61, .36, 1),
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        final entering = child.key == ValueKey(_index);
        final dx = 0.08 * _direction * (entering ? 1 : -1);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: Offset(dx, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_index),
        child: _SlideView(slide: widget.slides[_index]),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.slides.length; i++)
          Semantics(
            button: true,
            selected: i == _index,
            label: 'Go to slide ${i + 1}',
            child: GestureDetector(
              onTap: () => _go(i, manual: true),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                // Padding enlarges the tap target around the small dot.
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final FeatureSlide slide;

  @override
  Widget build(BuildContext context) {
    return AssetOr(
      slide.asset,
      fit: BoxFit.cover,
      placeholder: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, LandingColors.mauve],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: LandingColors.red800,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(slide.icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 18),
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: LandingColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                slide.caption,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: LandingColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round arrow overlaid on the screen edge; fades in while hovered.
class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.visible,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final bool visible;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !visible,
          child: SizedBox.square(
            dimension: 34,
            child: IconButton.filled(
              tooltip: tooltip,
              onPressed: onTap,
              padding: EdgeInsets.zero,
              iconSize: 22,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                foregroundColor: LandingColors.red800,
                elevation: 3,
                shadowColor: Colors.black26,
              ),
              icon: Icon(icon),
            ),
          ),
        ),
      ),
    );
  }
}
