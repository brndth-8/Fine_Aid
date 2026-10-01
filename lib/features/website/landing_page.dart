/// Fine Aid public landing page — everything for the site at `/` lives in
/// this one file. Jump between parts by searching for the `####` banners;
/// each section inside SECTIONS starts with a `// 1. HERO`-style header.
///
/// Images: assets/web/ (see assets/web/README.md).
/// Contact details + download link: site_config.dart.
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

enum LandingSection { about, download, experts, contact }

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

  static double navHeight(BuildContext context) =>
      Breakpoints.isMobile(context) ? 72 : 104;

  void _scrollTo(LandingSection section) {
    _scaffoldKey.currentState?.closeEndDrawer();
    final box =
        _keys[section]!.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final target = (_scroll.offset + top - navHeight(context)).clamp(
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
    final nav = navHeight(context);
    final mobile = Breakpoints.isMobile(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      endDrawer: mobile ? _MobileMenu(onSelect: _scrollTo) : null,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: nav),
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeroSection(
                    minHeight: (MediaQuery.sizeOf(context).height - nav).clamp(
                      0,
                      double.infinity,
                    ),
                    onCta: () => _scrollTo(LandingSection.download),
                  ),
                  AboutSection(key: _keys[LandingSection.about]),
                  DownloadSection(
                    key: _keys[LandingSection.download],
                    onSeeMore: () => _scrollTo(LandingSection.experts),
                  ),
                  ExpertsIntroSection(key: _keys[LandingSection.experts]),
                  const MeetExpertsSection(),
                  const ConsultationSection(),
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
            height: nav,
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
      // Full width (not ContentWidth): logo hugs the left edge, links the
      // right edge, at any screen size.
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: mobile ? 16 : 40),
        child: Row(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onLogoTap,
                child: AnimatedLogo(width: mobile ? 110 : 170),
              ),
            ),
            const Spacer(),
            if (mobile)
              IconButton(
                tooltip: 'Open menu',
                onPressed: onMenu,
                icon: const Icon(Icons.menu, color: LandingColors.maroon),
              )
            else ...[
              _NavLink('ABOUT', () => onSelect(LandingSection.about)),
              const SizedBox(width: 56),
              _NavLink('EXPERTS', () => onSelect(LandingSection.experts)),
              const SizedBox(width: 56),
              _NavLink('CONTACT US', () => onSelect(LandingSection.contact)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Uppercase nav link; a red underline grows in from the left on hover.
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
                    color: _hover ? LandingColors.red600 : LandingColors.maroon,
                  ),
                ),
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
      title: Text(label, style: LandingText.nav().copyWith(fontSize: 18)),
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
              child: AnimatedLogo(width: 140),
            ),
            item('ABOUT', LandingSection.about),
            item('EXPERTS', LandingSection.experts),
            item('CONTACT US', LandingSection.contact),
          ],
        ),
      ),
    );
  }
}

// ######################################################################
// SECTIONS — hero, about, download, experts (intro / cards /
// consultation), brand statement, footer
// ######################################################################

// Website images in assets/web/ (see assets/web/README.md). Any file that is
// still missing is rendered as a soft gradient placeholder.
class _Img {
  static const hero = 'assets/web/hero.jpg'; // wooden medical blocks
  static const qr = 'assets/web/qr.png'; // app download QR code
  static const phoneFrame = 'assets/web/phone-frame.png'; // About phone
  static const phoneAngled = 'assets/web/phone-frame-angled.png'; // Download
  static const group1 = 'assets/web/expert-1.jpg'; // Galderma, Makati
  static const group2 = 'assets/web/expert-2.jpg'; // advisory session, SJDM
  static const deanne = 'assets/web/expert-deanne.jpg';
  static const samuel = 'assets/web/expert-samuel.jpg';
  static const morallas = 'assets/web/expert-morallas.jpg';
  static const consultationBg = 'assets/web/experts-bg.jpg'; // maroon waves
  static const worldMap = 'assets/web/world-map.png';
  static const footerBadge = 'assets/web/footer-badge.jpg'; // first-aid badge
  static const iconJournal = 'assets/web/icon-journal.png';
  static const iconStethoscope = 'assets/web/icon-stethoscope.png';
}

const _leadCopy =
    'First aid is more than just knowing how to put on a bandage.\n'
    'It is about having the capable confidence to step up.';

/// Scales a size between phone (375px) and wide desktop (1440px) widths.
double _fluid(BuildContext context, double phone, double desktop) {
  final w = MediaQuery.sizeOf(context).width;
  final t = ((w - 375) / (1440 - 375)).clamp(0.0, 1.0);
  return phone + (desktop - phone) * t;
}

/// Journal glyph from the design, tinted to [color].
class _JournalIcon extends StatelessWidget {
  const _JournalIcon({required this.color, this.size = 48});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _Img.iconJournal,
      width: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (_, _, _) => Icon(Icons.draw, color: color, size: size),
    );
  }
}

/// Camera inside a ring, as in the design.
class _CameraIcon extends StatelessWidget {
  const _CameraIcon({required this.color, this.size = 56});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: size * 0.06),
      ),
      child: Icon(Icons.photo_camera, color: color, size: size * 0.5),
    );
  }
}

// ============================================================
// 1. HERO
// ============================================================
class HeroSection extends StatelessWidget {
  const HeroSection({super.key, required this.minHeight, required this.onCta});

  final double minHeight;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final mobile = Breakpoints.isMobile(context);

    final headline = Column(
      children: [
        // Always two lines as in the design: shrink to fit rather than wrap.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'BE THE HELP\nUNTIL HELP ARRIVES',
            textAlign: TextAlign.center,
            style: LandingText.display(
              _fluid(context, 34, 76),
            ).copyWith(letterSpacing: _fluid(context, 2, 6)),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _leadCopy,
          textAlign: TextAlign.center,
          style: LandingText.body(
            color: LandingColors.accent,
            size: _fluid(context, 16, 22),
          ),
        ),
        const SizedBox(height: 36),
        PillButton(label: 'GET YOURS NOW', onPressed: onCta),
      ],
    );
    final cards = [
      const _FeatureCard(
        title: 'AI Camera',
        subtitle: 'For a quick preliminary assessment',
        icon: _CameraIcon(color: LandingColors.maroon),
      ),
      const _FeatureCard(
        title: 'Health Journal',
        subtitle: 'To track recovery over time',
        icon: _JournalIcon(color: LandingColors.maroon, size: 56),
      ),
      const _FeatureCard(
        title: 'Health Kit',
        subtitle: 'Guidance even through offline',
        icon: Icon(
          Icons.medical_services_outlined,
          color: LandingColors.maroon,
          size: 56,
        ),
      ),
    ];

    final background = Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AssetOr(
            _Img.hero,
            alignment: Alignment(-0.35, 0),
            placeholder: PhotoPlaceholder(
              colors: [Color(0xFFDCE6F2), Color(0xFFB9CBE0)],
            ),
          ),
          // Keeps the maroon headline readable over the photo.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white.withValues(alpha: mobile ? 0.55 : 0),
                  Colors.white.withValues(alpha: mobile ? 0.55 : 0.35),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              background,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 80),
                child: ContentWidth(child: Reveal(child: headline)),
              ),
            ],
          ),
          ColoredBox(
            color: LandingColors.pinkBg,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: ContentWidth(
                child: Column(
                  children: [
                    for (final card in cards)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Reveal(child: card),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight.clamp(0, 900)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          background,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 56),
            child: ContentWidth(
              child: Row(
                children: [
                  SizedBox(
                    width: 340,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < cards.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Reveal(
                              delay: Duration(milliseconds: 100 * i),
                              child: cards[i],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(child: Reveal(child: headline)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Widget icon;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        transform: Matrix4.translationValues(_hover ? 6 : 0, 0, 0),
        padding: const EdgeInsets.fromLTRB(22, 16, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hover ? 0.14 : 0.06),
              blurRadius: _hover ? 22 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: LandingColors.maroon,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      height: 1.5,
                      color: LandingColors.maroon,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            widget.icon,
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 2. ABOUT
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
    final width = MediaQuery.sizeOf(context).width;

    final heading = Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ABOUT',
            style: LandingText.display(
              _fluid(context, 48, 84),
            ).copyWith(letterSpacing: 2),
          ),
          Text(
            'YOUR SMART FIRST AID ASSISTANT',
            style: LandingText.body(
              color: LandingColors.accent,
              size: _fluid(context, 18, 32),
            ).copyWith(height: 1.2),
          ),
        ],
      ),
    );
    final textStyle = LandingText.body(
      color: LandingColors.ink,
      size: _fluid(context, 16, 20),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_p1, style: textStyle),
        const SizedBox(height: 22),
        Text(_p2, style: textStyle),
      ],
    );
    const photo = AssetOr(
      _Img.hero,
      alignment: Alignment(0.6, 0),
      placeholder: PhotoPlaceholder(),
    );
    final panelColor = const Color(0xFFE9E5E5).withValues(alpha: 0.9);

    if (mobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
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
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      color: panelColor,
                      child: text,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            Reveal(
              child: Center(
                child: PhoneCarousel(width: width < 400 ? 220 : 250),
              ),
            ),
          ],
        ),
      );
    }

    // Desktop: photo on the right half; gray text panel runs from behind the
    // phone across the photo.
    const phoneWidth = 250.0;
    return Stack(
      children: [
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: width * 0.5,
          child: photo,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 56, 0, 64),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: 28),
                Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: phoneWidth / 2 + 60),
                      child: Reveal(
                        delay: const Duration(milliseconds: 150),
                        child: Container(
                          color: panelColor,
                          padding: const EdgeInsets.fromLTRB(
                            phoneWidth / 2 + 44,
                            48,
                            40,
                            48,
                          ),
                          child: text,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 60),
                      child: Reveal(child: PhoneCarousel(width: phoneWidth)),
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
}

// ============================================================
// 3. DOWNLOAD
// ============================================================
class DownloadSection extends StatelessWidget {
  const DownloadSection({super.key, required this.onSeeMore});

  final VoidCallback onSeeMore;

  @override
  Widget build(BuildContext context) {
    final mobile = Breakpoints.isMobile(context);

    final copy = Column(
      children: [
        Text(
          'DOWNLOAD\nFINE AID',
          textAlign: TextAlign.center,
          style: LandingText.display(
            _fluid(context, 40, 72),
          ).copyWith(letterSpacing: _fluid(context, 2, 5)),
        ),
        const SizedBox(height: 14),
        Text(
          _leadCopy,
          textAlign: TextAlign.center,
          style: LandingText.body(
            color: LandingColors.accent,
            size: _fluid(context, 15, 19),
          ),
        ),
        // Room for the pink crosses between the text and the button.
        const SizedBox(height: 96),
        PillButton(label: 'SEE MORE', onPressed: onSeeMore, rounded: false),
      ],
    );
    // Pink crosses drawn around (never over) the copy.
    final decorated = CustomPaint(
      painter: const _CrossesPainter(),
      child: copy,
    );

    if (mobile) {
      return ClipRect(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: ContentWidth(
            child: Column(
              children: [
                Reveal(child: decorated),
                const SizedBox(height: 40),
                const Reveal(child: _DownloadPhone(width: 250)),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRect(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: ContentWidth(
          child: Row(
            children: [
              Expanded(
                flex: 11,
                child: Reveal(
                  child: SizedBox(
                    height: 540,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final qr = (c.maxWidth * 0.62).clamp(240.0, 360.0);
                        return Stack(
                          children: [
                            // Oversized QR peeking out behind the phone.
                            Positioned(
                              left: 0,
                              top: (540 - qr) / 2,
                              width: qr,
                              height: qr,
                              child: const _QrImage(faded: true),
                            ),
                            Positioned(
                              left: qr * 0.62,
                              top: 0,
                              bottom: 0,
                              child: const _DownloadPhone(width: 340),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(flex: 9, child: Reveal(child: decorated)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrImage extends StatelessWidget {
  const _QrImage({this.faded = false});

  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.8 : 1,
      child: AssetOr(
        _Img.qr,
        fit: BoxFit.contain,
        placeholder: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCFCFCF), width: 2),
          ),
          child: Text('QR CODE', style: LandingText.nav()),
        ),
      ),
    );
  }
}

/// Angled phone showing the QR code. Tapping the QR or "SCAN" opens the
/// download link — handy on phones, which can't scan their own screen.
class _DownloadPhone extends StatelessWidget {
  const _DownloadPhone({required this.width});

  final double width;

  // Screen opening inside phone-frame-angled.png, as fractions of the image.
  static const _l = 0.0322, _t = 0.052, _r = 0.6283, _b = 0.8092;
  static const _aspect = 1289 / 807;

  @override
  Widget build(BuildContext context) {
    final height = width * _aspect;
    final screenW = width * (_r - _l);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: width * _l,
            top: height * _t,
            width: screenW,
            height: height * (_b - _t),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(screenW * 0.13),
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    screenW * 0.08,
                    screenW * 0.2,
                    screenW * 0.08,
                    screenW * 0.1,
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        AnimatedLogo.defaultAsset,
                        width: screenW * 0.55,
                      ),
                      SizedBox(height: screenW * 0.08),
                      Link(
                        uri: SiteConfig.downloadUri,
                        target: LinkTarget.blank,
                        builder: (context, open) => MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: open,
                            child: CustomPaint(
                              painter: const _ScanBracketsPainter(),
                              child: Padding(
                                padding: EdgeInsets.all(screenW * 0.08),
                                child: const AspectRatio(
                                  aspectRatio: 1,
                                  child: _QrImage(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Link(
                        uri: SiteConfig.downloadUri,
                        target: LinkTarget.blank,
                        builder: (context, open) => SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: open,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LandingColors.maroon,
                              side: const BorderSide(
                                color: LandingColors.maroon,
                                width: 2,
                              ),
                              shape: const StadiumBorder(),
                              padding: EdgeInsets.symmetric(
                                vertical: screenW * 0.035,
                              ),
                            ),
                            child: Text(
                              'SCAN',
                              style: LandingText.body(
                                color: LandingColors.maroon,
                                size: screenW * 0.08,
                              ).copyWith(letterSpacing: 3, height: 1.2),
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
          Positioned.fill(
            child: IgnorePointer(
              child: Image.asset(_Img.phoneAngled, fit: BoxFit.fill),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded pink crosses from the design, positioned relative to the
/// download copy (fractions of its box; values outside 0–1 sit outside it).
class _CrossesPainter extends CustomPainter {
  const _CrossesPainter();

  // (x, y, size in px) — placed in the margins and in the gap above the
  // button, where the copy has no text.
  static const _spots = [
    (-0.04, -0.10, 40.0),
    (1.00, -0.04, 72.0),
    (0.12, 0.715, 64.0),
    (0.35, 0.70, 34.0),
    (0.92, 0.68, 34.0),
    (0.90, 1.14, 70.0),
    (0.62, 1.26, 42.0),
    (0.06, 1.24, 30.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFD8B2B3);
    for (final (fx, fy, s) in _spots) {
      final c = Offset(size.width * fx, size.height * fy);
      final arm = s * 0.36;
      final r = Radius.circular(s * 0.09);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: s, height: arm),
          r,
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: arm, height: s),
          r,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Maroon scanner corner brackets around the QR.
class _ScanBracketsPainter extends CustomPainter {
  const _ScanBracketsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final len = s * 0.18;
    final paint = Paint()
      ..color = LandingColors.maroon
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, len)
      ..lineTo(0, 0)
      ..lineTo(len, 0)
      ..moveTo(w - len, 0)
      ..lineTo(w, 0)
      ..lineTo(w, len)
      ..moveTo(w, h - len)
      ..lineTo(w, h)
      ..lineTo(w - len, h)
      ..moveTo(len, h)
      ..lineTo(0, h)
      ..lineTo(0, h - len);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// 4. EXPERTS — intro with slanted consultation photos
// ============================================================
class ExpertsIntroSection extends StatelessWidget {
  const ExpertsIntroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = Breakpoints.isMobile(context);

    final text = Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'EXPERTS',
                style: LandingText.body(
                  color: LandingColors.maroon,
                  size: 20,
                ).copyWith(letterSpacing: 1),
              ),
              const SizedBox(width: 12),
              Container(width: 100, height: 1.5, color: LandingColors.maroon),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Backed by Credentials\nBuilt for Safety',
            style: LandingText.heading(_fluid(context, 32, 50)),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              'Our protocols are developed in close alignment with medical '
              'standards and industry regulations to ensure reliability.',
              style: LandingText.body(
                color: LandingColors.maroon,
                size: _fluid(context, 16, 19),
              ),
            ),
          ),
        ],
      ),
    );

    const photos = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: AssetOr(_Img.group1, placeholder: PhotoPlaceholder())),
        Expanded(child: AssetOr(_Img.group2, placeholder: PhotoPlaceholder())),
      ],
    );

    if (mobile) {
      return Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContentWidth(child: text),
            const SizedBox(height: 32),
            const SizedBox(height: 460, child: photos),
          ],
        ),
      );
    }

    return SizedBox(
      height: 640,
      child: Stack(
        children: [
          Positioned.fill(
            child: ContentWidth(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(widthFactor: 0.45, child: text),
              ),
            ),
          ),
          // Maroon stripe peeking out along the slanted edge, then photos.
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: MediaQuery.sizeOf(context).width * 0.56,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipPath(
                  clipper: const _SlantClipper(),
                  child: const ColoredBox(color: LandingColors.maroon),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: ClipPath(
                    clipper: const _SlantClipper(),
                    child: photos,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Parallelogram-ish clip: left edge slants from top-right to bottom-left.
class _SlantClipper extends CustomClipper<Path> {
  const _SlantClipper();

  @override
  Path getClip(Size size) {
    final slant = size.height * 0.2;
    return Path()
      ..moveTo(slant, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ============================================================
// 5. MEET OUR EXPERTS
// ============================================================
class _Expert {
  const _Expert(this.name, this.role, this.photo);
  final String name;
  final String role;
  final String photo;
}

const _experts = [
  _Expert('Dr. Deanne Asdala', 'Medical Affairs Manager', _Img.deanne),
  _Expert(
    'Mr. Samuel Evan Pacamparra,',
    'RPh, Regulatory Affairs Manager',
    _Img.samuel,
  ),
  _Expert('Dr. Anthony Morallas', 'Physician (Anesthesiology)', _Img.morallas),
];

class MeetExpertsSection extends StatelessWidget {
  const MeetExpertsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = Breakpoints.isMobile(context);
    final title = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Container(
            width: 100,
            height: 1.5,
            color: LandingColors.maroon,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          flex: 4,
          child: Text(
            'MEET OUR EXPERTS',
            textAlign: TextAlign.center,
            style: LandingText.heading(_fluid(context, 22, 30)),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Container(
            width: 100,
            height: 1.5,
            color: LandingColors.maroon,
          ),
        ),
      ],
    );
    final cards = [
      for (var i = 0; i < _experts.length; i++)
        Reveal(
          delay: Duration(milliseconds: mobile ? 0 : 100 * i),
          child: _ExpertCard(expert: _experts[i]),
        ),
    ];

    return ColoredBox(
      color: LandingColors.pinkBg,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: mobile ? 56 : 72),
        child: ContentWidth(
          child: Column(
            children: [
              Reveal(child: title),
              const SizedBox(height: 44),
              if (mobile)
                for (final card in cards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: card,
                    ),
                  )
              else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 44),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpertCard extends StatefulWidget {
  const _ExpertCard({required this.expert});

  final _Expert expert;

  @override
  State<_ExpertCard> createState() => _ExpertCardState();
}

class _ExpertCardState extends State<_ExpertCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.expert;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -6 : 0, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFAFD),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: LandingColors.maroon.withValues(
                alpha: _hover ? 0.16 : 0.05,
              ),
              blurRadius: _hover ? 28 : 10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Semantics(
                image: true,
                label: 'Photo of ${e.name}',
                child: AssetOr(
                  e.photo,
                  alignment: Alignment.topCenter,
                  placeholder: const ColoredBox(
                    color: Color(0xFFEDE3E4),
                    child: Icon(
                      Icons.person,
                      size: 96,
                      color: Color(0xFFCBB2B5),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
              child: Column(
                children: [
                  Text(
                    e.name,
                    textAlign: TextAlign.center,
                    style: LandingText.heading(22),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        padding: const EdgeInsets.all(11),
                        decoration: const BoxDecoration(
                          color: LandingColors.maroon,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          _Img.iconStethoscope,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.medical_services,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          e.role,
                          textAlign: TextAlign.center,
                          style: LandingText.body(
                            color: LandingColors.ink,
                            size: 17,
                          ).copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 6. CONSULTATION — "Get to know them?"
// ============================================================
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

class ConsultationSection extends StatelessWidget {
  const ConsultationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = Breakpoints.isMobile(context);

    Widget feature(Widget icon, String label) => SizedBox(
      width: mobile ? 96 : 150,
      child: Column(
        children: [
          SizedBox(height: 56, child: Center(child: icon)),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: LandingText.body(color: Colors.white, size: 17),
          ),
        ],
      ),
    );
    Widget divider() => Container(
      width: 1,
      height: 76,
      margin: EdgeInsets.symmetric(horizontal: mobile ? 6 : 20),
      color: Colors.white.withValues(alpha: 0.6),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            const Positioned.fill(
              child: AssetOr(
                _Img.consultationBg,
                alignment: Alignment.bottomRight,
                placeholder: ColoredBox(color: LandingColors.maroon),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: mobile ? 56 : 88),
              child: ContentWidth(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: mobile ? 0 : 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Reveal(
                        child: Text(
                          'Get to know them?',
                          style: LandingText.heading(
                            _fluid(context, 32, 56),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: mobile ? 28 : 64),
                      for (final p in _consultationParagraphs)
                        Reveal(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Text(
                              p,
                              textAlign: mobile
                                  ? TextAlign.start
                                  : TextAlign.justify,
                              style: LandingText.body(
                                color: Colors.white,
                                size: _fluid(context, 16, 19),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        ColoredBox(
          color: LandingColors.bandDark,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                feature(
                  const _JournalIcon(color: Colors.white, size: 50),
                  'Journal',
                ),
                divider(),
                feature(
                  const _CameraIcon(color: Colors.white, size: 54),
                  'AI Camera',
                ),
                divider(),
                feature(
                  const Icon(
                    Icons.medical_services_outlined,
                    color: Colors.white,
                    size: 54,
                  ),
                  'First-Aid kit',
                ),
              ],
            ),
          ),
        ),
        Container(height: 2, color: Colors.white),
        Container(height: 14, color: LandingColors.maroon),
      ],
    );
  }
}

// ============================================================
// 7. BRAND STATEMENT
// ============================================================
class BrandStatementSection extends StatelessWidget {
  const BrandStatementSection({super.key});

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).width < 480;
    return Stack(
      children: [
        const Positioned.fill(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: AssetOr(
              _Img.worldMap,
              fit: BoxFit.contain,
              placeholder: SizedBox.shrink(),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: small ? 100 : 170),
          child: ContentWidth(
            child: Column(
              children: [
                AnimatedLogo(
                  width: _fluid(context, 200, 340),
                  trigger: LogoTrigger.scroll,
                ),
                const SizedBox(height: 18),
                Reveal(
                  child: Text(
                    '“Awareness to first aid can make a real difference.”',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hind(
                      fontSize: _fluid(context, 19, 32),
                      fontStyle: FontStyle.italic,
                      color: LandingColors.deep,
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

// ============================================================
// 8. FOOTER
// ============================================================
class LandingFooter extends StatelessWidget {
  const LandingFooter({super.key, required this.onNavigate});

  final ValueChanged<LandingSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    final mobile = Breakpoints.isMobile(context);
    final align = mobile ? CrossAxisAlignment.center : CrossAxisAlignment.start;

    final brand = Column(
      crossAxisAlignment: align,
      children: [
        const AnimatedLogo(width: 200, trigger: LogoTrigger.scroll),
        Text(
          'YOUR SMART FIRST AID ASSISTANT',
          style: LandingText.body(color: LandingColors.footerRed, size: 15),
        ),
        const SizedBox(height: 28),
        // First-aid badge, dimmed onto gray as in the design.
        Container(
          width: 220,
          height: 210,
          color: const Color(0xFF8E8E8E),
          padding: const EdgeInsets.all(18),
          child: Opacity(
            opacity: 0.62,
            child: Image.asset(
              _Img.footerBadge,
              fit: BoxFit.contain,
              color: const Color(0xFF8E8E8E),
              colorBlendMode: BlendMode.multiply,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );

    final contact = Column(
      crossAxisAlignment: align,
      children: [
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
          iconTurns: -0.08,
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
        const SizedBox(height: 36),
        _ContactRow(
          icon: Icons.copyright,
          center: mobile,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '2026 '),
                TextSpan(
                  text: 'Fine Aid',
                  style: _footerText.copyWith(
                    color: LandingColors.footerRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '. All rights reserved'),
              ],
            ),
            style: _footerText,
          ),
        ),
      ],
    );

    final menu = Column(
      crossAxisAlignment: align,
      children: [
        Text(
          'Main Menu',
          style: LandingText.body(
            color: LandingColors.footerRed,
            size: 21,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 22),
        _FooterLink('About', onTap: () => onNavigate(LandingSection.about)),
        const SizedBox(height: 14),
        _FooterLink(
          'Validity',
          onTap: () => onNavigate(LandingSection.experts),
        ),
        const SizedBox(height: 14),
        _FooterLink(
          'Contact Us',
          onTap: () => onNavigate(LandingSection.contact),
        ),
      ],
    );

    return ColoredBox(
      color: LandingColors.footer,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: mobile ? 48 : 64),
        child: ContentWidth(
          child: mobile
              ? Column(
                  children: [
                    brand,
                    const SizedBox(height: 40),
                    contact,
                    const SizedBox(height: 40),
                    menu,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 9, child: brand),
                    Expanded(
                      flex: 11,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 76),
                        child: contact,
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 76),
                        child: menu,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

final _footerText = GoogleFonts.hind(
  color: Colors.white,
  fontSize: 18,
  height: 1.45,
);

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.child,
    this.center = false,
    this.iconTurns = 0,
  });

  final IconData icon;
  final Widget child;
  final bool center;
  final double iconTurns;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: center
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RotationTransition(
            turns: AlwaysStoppedAnimation(iconTurns),
            child: Icon(icon, color: LandingColors.footerRed, size: 26),
          ),
          const SizedBox(width: 16),
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
            color: _hover ? LandingColors.footerRed : Colors.white,
            decoration: _hover ? TextDecoration.underline : null,
            decorationColor: LandingColors.footerRed,
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

  // Palette sampled from the design PDF.
  static const maroon = Color(0xFF5B0D0D); // headings, buttons
  static const accent = Color(0xFF8D2F2F); // subtitles
  static const deep = Color(0xFF790000); // quote
  static const bandDark = Color(0xFF4A0606); // consultation icon band
  static const pinkBg = Color(0xFFFDF1F0); // Meet Our Experts background
  static const footer = Color(0xFF1C1C1E);
  static const footerRed = Color(0xFFB0302C);

  static const red900 = Color(0xFF6E0F0F);
  static const red800 = Color(0xFF8B1A1A);
  static const red600 = Color(0xFFC41E1E);
  static const mauve = Color(0xFFF3E3E5);
  static const ink = Color(0xFF1C1A1D);
  static const body = Color(0xFF4A4A4A);
  static const muted = Color(0xFF8A8A8A);
}

/// Width breakpoints shared by every section.
class Breakpoints {
  Breakpoints._();

  static const double mobile = 820;
  static const double tablet = 1024;
  static const double maxContent = 1240;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tablet;
}

/// Fonts from the design: League Spartan (display), Canva Sans → Hind
/// (closest Google Font), Roboto (feature cards).
class LandingText {
  LandingText._();

  /// Big uppercase display lines (hero, ABOUT, DOWNLOAD).
  static TextStyle display(double size, {Color color = LandingColors.maroon}) =>
      GoogleFonts.leagueSpartan(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.08,
        color: color,
      );

  /// Bold sentence-case headings (experts, consultation).
  static TextStyle heading(double size, {Color color = LandingColors.maroon}) =>
      GoogleFonts.hind(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: color,
      );

  static TextStyle body({Color color = LandingColors.body, double size = 16}) =>
      GoogleFonts.hind(fontSize: size, height: 1.55, color: color);

  static TextStyle nav({Color color = LandingColors.maroon}) =>
      GoogleFonts.leagueSpartan(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: color,
      );
}

/// Centers content and caps it at the site's max width.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gutter = MediaQuery.sizeOf(context).width < 480 ? 16.0 : 32.0;
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

/// Maroon call-to-action button: pill ("GET YOURS NOW") or rounded
/// rectangle ("SEE MORE").
class PillButton extends StatefulWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.rounded = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool rounded;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedSlide(
        offset: Offset(0, _hover ? -0.06 : 0),
        duration: const Duration(milliseconds: 200),
        child: FilledButton(
          onPressed: widget.onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _hover
                ? LandingColors.red800
                : LandingColors.maroon,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: widget.rounded ? 40 : 76,
              vertical: widget.rounded ? 22 : 18,
            ),
            shape: widget.rounded
                ? const StadiumBorder()
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
            elevation: _hover ? 8 : 2,
            textStyle: GoogleFonts.leagueSpartan(
              fontSize: widget.rounded ? 20 : 28,
              fontWeight: FontWeight.w700,
              letterSpacing: widget.rounded ? 1 : 0.5,
            ),
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

/// Kept for the 404 page in web_app.dart.
class RedButton extends StatelessWidget {
  const RedButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      PillButton(label: label.toUpperCase(), onPressed: onPressed);
}

/// Shows an image asset, or [placeholder] until that asset is supplied.
/// Expects tight constraints from its parent (Positioned.fill, SizedBox, …).
class AssetOr extends StatelessWidget {
  const AssetOr(
    this.asset, {
    super.key,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final String asset;
  final Widget placeholder;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: fit,
      alignment: alignment,
      errorBuilder: (_, _, _) => placeholder,
    );
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
                style: LandingText.nav(
                  color: LandingColors.red900.withValues(alpha: 0.45),
                ).copyWith(fontSize: 13),
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
// FEATURE CAROUSEL — app screenshots inside the phone frame (About)
// ######################################################################

class FeatureSlide {
  const FeatureSlide({required this.asset, required this.title});

  /// Phone screenshot (≈9:19). A plain placeholder shows if it's missing.
  final String asset;
  final String title;
}

/// Add more slides by dropping screen-N.jpg into assets/web/ and listing it.
const featureSlides = [
  FeatureSlide(asset: 'assets/web/screen-1.jpg', title: 'AI Vision Camera'),
  FeatureSlide(asset: 'assets/web/screen-2.jpg', title: 'First Aid Dashboard'),
  FeatureSlide(asset: 'assets/web/screen-4.jpg', title: 'Health Profile'),
  FeatureSlide(asset: 'assets/web/screen-5.jpg', title: 'Health Journal'),
  FeatureSlide(asset: 'assets/web/screen-3.jpg', title: 'Journal Entry'),
];

/// Auto-rotating screenshots inside the phone mockup. Advances every
/// [interval]; pauses on hover (desktop) or tap (touch); swipe, the hover
/// arrows, or the dots navigate.
class PhoneCarousel extends StatefulWidget {
  const PhoneCarousel({
    super.key,
    this.slides = featureSlides,
    this.width = 250,
    this.interval = const Duration(milliseconds: 4500),
  });

  final List<FeatureSlide> slides;
  final double width;
  final Duration interval;

  @override
  State<PhoneCarousel> createState() => _PhoneCarouselState();
}

class _PhoneCarouselState extends State<PhoneCarousel> {
  // Screen opening inside phone-frame.png, as fractions of the image.
  static const _l = 0.0395, _t = 0.0158, _r = 0.9588, _b = 0.9842;
  static const _aspect = 1204 / 583;

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
    final w = widget.width;
    final h = w * _aspect;
    final screenW = w * (_r - _l);
    return Semantics(
      label:
          'Fine Aid app: ${widget.slides[_index].title}, '
          'slide ${_index + 1} of ${widget.slides.length}',
      child: MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Positioned(
                left: w * _l,
                top: h * _t,
                width: screenW,
                height: h * (_b - _t),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(screenW * 0.14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: _toggleTapPause,
                        onHorizontalDragEnd: (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v.abs() < 150) return;
                          _go(v < 0 ? _index + 1 : _index - 1, manual: true);
                        },
                        child: ColoredBox(
                          color: const Color(0xFFF1F1F3),
                          child: _slides(),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(-0.92, 0),
                        child: _Arrow(
                          visible: _hover,
                          icon: Icons.chevron_left,
                          tooltip: 'Previous slide',
                          onTap: () => _go(_index - 1, manual: true),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0.92, 0),
                        child: _Arrow(
                          visible: _hover,
                          icon: Icons.chevron_right,
                          tooltip: 'Next slide',
                          onTap: () => _go(_index + 1, manual: true),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: screenW * 0.035,
                        child: Center(child: _dots()),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Image.asset(
                    _Img.phoneFrame,
                    fit: BoxFit.fill,
                    errorBuilder: (_, _, _) => DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(width: 8),
                        borderRadius: BorderRadius.circular(w * 0.15),
                      ),
                    ),
                  ),
                ),
              ),
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
        child: AssetOr(
          widget.slides[_index].asset,
          alignment: Alignment.topCenter,
          placeholder: Center(
            child: Text(
              widget.slides[_index].title,
              style: LandingText.heading(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
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
                      horizontal: 3,
                      vertical: 6,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: i == _index ? 14 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? LandingColors.maroon
                            : const Color(0xFFB9B4B4),
                        borderRadius: BorderRadius.circular(99),
                      ),
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
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !visible,
        child: SizedBox.square(
          dimension: 32,
          child: IconButton.filled(
            tooltip: tooltip,
            onPressed: onTap,
            padding: EdgeInsets.zero,
            iconSize: 22,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.92),
              foregroundColor: LandingColors.maroon,
              elevation: 3,
              shadowColor: Colors.black26,
            ),
            icon: Icon(icon),
          ),
        ),
      ),
    );
  }
}
