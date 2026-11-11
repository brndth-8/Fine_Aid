import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// One bullet of "Why Transparency Matters?": a bold lead, then its text.
class LicenseBullet {
  final String lead;
  final String text;
  const LicenseBullet(this.lead, this.text);
}

/// A technology in "Core Technologies & Stack Overview".
class LicenseTech {
  final String name;
  final String whatItIs;
  final String purpose;

  /// "Key Services Used" (name, description), when the technology has them.
  final List<(String, String)> keyServices;

  const LicenseTech({
    required this.name,
    required this.whatItIs,
    required this.purpose,
    this.keyServices = const [],
  });
}

/// Settings > About Application > View Licenses: "Application Licenses &
/// Technology Disclosure", English (the wording of VIEW LICENSES.pdf) and
/// Filipino (a translation of it; the PDF has none).
class LicensesStrings {
  final String viewLicenses;
  final String title;
  final String intro;
  final String whyTitle;
  final String whyIntro;
  final List<LicenseBullet> whyBullets;
  final String appVersion;
  final String stackTitle;
  final String whatItIsLabel;
  final String purposeLabel;
  final String keyServicesLabel;
  final List<LicenseTech> technologies;
  final String liabilityTitle;
  final String liabilityBody;

  const LicensesStrings({
    required this.viewLicenses,
    required this.title,
    required this.intro,
    required this.whyTitle,
    required this.whyIntro,
    required this.whyBullets,
    required this.appVersion,
    required this.stackTitle,
    required this.whatItIsLabel,
    required this.purposeLabel,
    required this.keyServicesLabel,
    required this.technologies,
    required this.liabilityTitle,
    required this.liabilityBody,
  });

  static LicensesStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = LicensesStrings(
    viewLicenses: 'View Licenses',
    title: 'Application Licenses & Technology Disclosure',
    intro:
        'Welcome to Fine Aid! We believe in full transparency regarding the '
        'software, infrastructure, and artificial intelligence models that '
        'power your experience. Below is a breakdown of the core '
        'technologies, APIs, and subscriptions integrated into our platform.',
    whyTitle: 'Why Transparency Matters?',
    whyIntro:
        'Transparency is fundamental to building trust between our '
        'application and our users. Being open about the technologies and '
        'third-party services we use is important for several key reasons:',
    whyBullets: [
      LicenseBullet(
        'Data Privacy & Security:',
        'You have a right to know where your data is processed, stored, and '
            'secured. Understanding our infrastructure reassures you that '
            'industry-standard security protocols protect your information.',
      ),
      LicenseBullet(
        'AI Accountability:',
        'As our app integrates advanced artificial intelligence features, '
            'transparency ensures you understand when and how AI is assisting '
            'you and gives clarity over automated processing.',
      ),
      LicenseBullet(
        'Informed Consent:',
        'Knowing which services handle important functions such as '
            'Semaphore delivering verification codes to your phone, helps you '
            'understand the complete ecosystem powering your daily app '
            'experience.',
      ),
    ],
    appVersion: 'App Version: v1.0.1',
    stackTitle: 'Core Technologies & Stack Overview',
    whatItIsLabel: 'What it is:',
    purposeLabel: 'Purpose:',
    keyServicesLabel: 'Key Services Used:',
    technologies: [
      LicenseTech(
        name: 'Gemini Flash (Google AI)',
        whatItIs:
            'A lightweight artificial intelligence model developed by Google '
            'designed for fast inference and multimodal reasoning.',
        purpose:
            'Powers our integrated AI features, intelligent assistance, '
            'automated analysis, and response generation within the app.',
      ),
      LicenseTech(
        name: 'Firebase (Google Cloud)',
        whatItIs:
            'An app development platform and cloud backend service hosted by '
            'Google.',
        purpose: 'Serves as our core backend infrastructure.',
        keyServices: [
          (
            'Firebase Authentication:',
            'Secure user sign-in and account management.',
          ),
          (
            'Cloud Firestore / Database:',
            'Secure data storage and synchronization.',
          ),
        ],
      ),
      LicenseTech(
        name: 'Semaphore SMS API',
        whatItIs:
            'A cloud-based messaging gateway service primarily utilized for '
            'high-delivery-rate text messaging.',
        purpose:
            'Used for sending verification codes directly to your mobile '
            'device',
      ),
      LicenseTech(
        name: 'Flutter (Google)',
        whatItIs:
            'An open-source, multi-platform UI software development kit '
            'created by Google for building natively compiled applications.',
        purpose:
            'The multi-platform UI framework used to build our mobile '
            'application and web for admin and landing page.',
      ),
    ],
    liabilityTitle: 'Third-Party Liability & Disclaimer',
    liabilityBody:
        'Our application relies on third-party cloud infrastructure and APIs '
        '(including Firebase, Google AI, and Semaphore). While we strive for '
        '100% uptime, we are not directly liable for service interruptions '
        'originating from these third-party providers.',
  );

  static const tl = LicensesStrings(
    viewLicenses: 'Tingnan ang mga Lisensya',
    title: 'Mga Lisensya ng Application at Pagbubunyag ng Teknolohiya',
    intro:
        'Maligayang pagdating sa Fine Aid! Naniniwala kami sa ganap na '
        'transparency tungkol sa software, imprastraktura, at mga modelo ng '
        'artificial intelligence na nagpapatakbo ng iyong karanasan. Narito '
        'ang detalye ng mga pangunahing teknolohiya, API, at subscription na '
        'isinama sa aming platform.',
    whyTitle: 'Bakit Mahalaga ang Transparency?',
    whyIntro:
        'Ang transparency ay pundasyon ng pagbuo ng tiwala sa pagitan ng '
        'aming application at ng aming mga gumagamit. Mahalaga ang pagiging '
        'bukas tungkol sa mga teknolohiya at serbisyo ng ikatlong panig na '
        'ginagamit namin sa ilang pangunahing dahilan:',
    whyBullets: [
      LicenseBullet(
        'Pagkapribado at Seguridad ng Datos:',
        'May karapatan kang malaman kung saan pinoproseso, iniimbak, at '
            'sinisiguro ang iyong datos. Ang pag-unawa sa aming imprastraktura '
            'ay nagbibigay ng kapanatagan na pinoprotektahan ng mga '
            'protokol sa seguridad na pamantayan ng industriya ang iyong '
            'impormasyon.',
      ),
      LicenseBullet(
        'Pananagutan ng AI:',
        'Dahil isinasama ng aming app ang mga advanced na tampok ng '
            'artificial intelligence, tinitiyak ng transparency na nauunawaan '
            'mo kung kailan at paano ka tinutulungan ng AI at nagbibigay ng '
            'linaw sa awtomatikong pagproseso.',
      ),
      LicenseBullet(
        'Kaalamang Pahintulot:',
        'Ang pagkaalam kung aling mga serbisyo ang humahawak ng mahahalagang '
            'tungkulin, tulad ng Semaphore na nagpapadala ng mga verification '
            'code sa iyong telepono, ay tumutulong sa iyong maunawaan ang '
            'buong ecosystem na nagpapatakbo ng iyong pang-araw-araw na '
            'karanasan sa app.',
      ),
    ],
    appVersion: 'Bersyon ng App: v1.0.1',
    stackTitle: 'Pangunahing Teknolohiya at Pangkalahatang-ideya ng Stack',
    whatItIsLabel: 'Ano ito:',
    purposeLabel: 'Layunin:',
    keyServicesLabel: 'Mga Pangunahing Serbisyong Ginagamit:',
    technologies: [
      LicenseTech(
        name: 'Gemini Flash (Google AI)',
        whatItIs:
            'Isang magaan na modelo ng artificial intelligence na binuo ng '
            'Google para sa mabilis na pagproseso at multimodal na pangangatwiran.',
        purpose:
            'Nagpapagana sa aming mga isinamang tampok ng AI, matalinong '
            'tulong, awtomatikong pagsusuri, at pagbuo ng tugon sa loob ng '
            'app.',
      ),
      LicenseTech(
        name: 'Firebase (Google Cloud)',
        whatItIs:
            'Isang platform sa pagbuo ng app at serbisyong cloud backend na '
            'hino-host ng Google.',
        purpose: 'Nagsisilbing pangunahing imprastraktura ng aming backend.',
        keyServices: [
          (
            'Firebase Authentication:',
            'Ligtas na pag-sign in ng user at pamamahala ng account.',
          ),
          (
            'Cloud Firestore / Database:',
            'Ligtas na pag-iimbak at pag-sync ng datos.',
          ),
        ],
      ),
      LicenseTech(
        name: 'Semaphore SMS API',
        whatItIs:
            'Isang cloud-based na serbisyong gateway ng pagmemensahe na '
            'pangunahing ginagamit para sa text messaging na mataas ang '
            'delivery rate.',
        purpose:
            'Ginagamit sa pagpapadala ng mga verification code direkta sa '
            'iyong mobile device',
      ),
      LicenseTech(
        name: 'Flutter (Google)',
        whatItIs:
            'Isang open-source, multi-platform na UI software development '
            'kit na nilikha ng Google para sa pagbuo ng mga natively compiled '
            'na aplikasyon.',
        purpose:
            'Ang multi-platform na UI framework na ginamit sa pagbuo ng aming '
            'mobile application at ng web para sa admin at landing page.',
      ),
    ],
    liabilityTitle: 'Pananagutan ng Ikatlong Panig at Paunawa',
    liabilityBody:
        'Umaasa ang aming application sa cloud infrastructure at mga API ng '
        'ikatlong panig (kabilang ang Firebase, Google AI, at Semaphore). '
        'Bagama\'t nagsisikap kaming magkaroon ng 100% uptime, hindi kami '
        'direktang mananagot sa mga pagkaantala ng serbisyo na nagmumula sa '
        'mga ikatlong panig na tagapagbigay na ito.',
  );
}
