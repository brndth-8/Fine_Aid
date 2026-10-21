import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// One block of the Terms & Conditions: a heading, then an optional
/// paragraph and/or a bullet list (in that order).
///
/// [subheader] draws the heading one level down (a heading inside a main
/// section); [warning] draws the paragraph as a boxed notice, for the
/// disclaimers that must stand out. An empty [header] draws no heading (the
/// opening paragraph).
class TermsSection {
  final String header;
  final bool subheader;
  final String? paragraph;
  final bool warning;
  final List<String> bullets;

  const TermsSection({
    required this.header,
    this.subheader = false,
    this.paragraph,
    this.warning = false,
    this.bullets = const [],
  });
}

/// Terms & Conditions screen text (English + Tagalog). The English follows
/// the "All Information Needed in the Application" document, in its order and
/// headings. Tagalog is a plain-language translation and must be reviewed
/// before release, as this is legal/medical text.
class TermsStrings {
  final String title;
  final String scrollHint;
  final String agree;
  final String saveError;
  final List<TermsSection> sections;

  const TermsStrings({
    required this.title,
    required this.scrollHint,
    required this.agree,
    required this.saveError,
    required this.sections,
  });

  static TermsStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = TermsStrings(
    title: 'Terms & Conditions',
    scrollHint: 'Please scroll to the end to continue.',
    agree: 'I Agree & Continue',
    saveError: 'Could not save your acceptance. Please try again.',
    sections: [
      TermsSection(
        header: '',
        paragraph:
            'Please read these Terms and Conditions carefully before using '
            'the App. By downloading, accessing, or using Fine Aid, you agree '
            'to be bound by these Terms. If you do not agree with all these '
            'Terms, do not use or access the App.',
      ),
      TermsSection(header: 'MEDICAL DISCLAIMER & EMERGENCY SERVICES'),
      TermsSection(
        header: 'NOT FOR EMERGENCIES',
        subheader: true,
        warning: true,
        paragraph:
            'THE APP IS NOT INTENDED FOR MEDICAL EMERGENCIES. IF YOU ARE '
            'EXPERIENCING A MEDICAL EMERGENCY, LIFE-THREATENING CONDITION, OR '
            'SEVERE SYMPTOMS, IMMEDIATELY CALL YOUR LOCAL EMERGENCY SERVICES '
            '(E.G., 911 OR YOUR LOCAL EMERGENCY NUMBER) OR VISIT THE NEAREST '
            'HOSPITAL EMERGENCY ROOM.',
      ),
      TermsSection(
        header: 'NOT A SUBSTITUTE FOR PROFESSIONAL MEDICAL CONSULTATION',
        subheader: true,
        paragraph:
            'Fine Aid is developed by student developers for educational and '
            'informational support only. While the first aid protocols and '
            'content within the App are curated based on established '
            'guidelines and validated by licensed medical practitioners, the '
            'App is not a licensed medical device, software as a medical '
            'device (SaMD), or a substitute for professional medical advice, '
            'clinical diagnosis, or treatment.\n\n'
            'Never disregard, delay, or avoid seeking professional medical '
            'advice or treatment. If you suspect you have a medical '
            'condition, infection, or severe injury, always consult a '
            'qualified healthcare professional.',
      ),
      TermsSection(
        header: 'NO DOCTOR–PATIENT RELATIONSHIP',
        subheader: true,
        paragraph:
            'Using general features of the App does not create a '
            'doctor-patient relationship. A professional relationship is '
            'established solely between you and a specific qualified '
            'healthcare provider during a formal healthcare consultation '
            'outside of this App.',
      ),
      TermsSection(header: 'APP USAGE & ACCOUNT TERMS'),
      TermsSection(
        header: 'Eligibility',
        subheader: true,
        paragraph:
            'You must be at least 18 years old (or the age of majority in '
            'your jurisdiction) to use the App independently. Minors may only '
            'use the App under the supervision of a parent or legal '
            'guardian.',
      ),
      TermsSection(
        header: 'Account Registration & Security',
        subheader: true,
        bullets: [
          'You must provide accurate, current, and complete information '
              'during registration.',
          'You are responsible for maintaining the confidentiality of your '
              'login credentials (including Username, Password, One-Time '
              'Password (OTP), and Email Address).',
          'You agree to notify us immediately of any unauthorized use or '
              'security breach of your account.',
        ],
      ),
      TermsSection(
        header: 'AI Camera Feature & Permissions',
        subheader: true,
        bullets: [
          'Purpose and Usage: The App requires access to your device’s '
              'camera to capture images of superficial injuries or wounds. '
              'The integrated AI model analyzes these images to generate '
              'immediate, step-by-step first aid guidance and suggestions.',
          'Limitations: The AI Camera is an automated guidance tool and '
              'cannot diagnose medical conditions, infections, or deep '
              'trauma. Always consult a qualified healthcare professional for '
              'proper clinical evaluation.',
          'Consent: By enabling camera permissions, you consent to the '
              'processing of captured images solely for providing first aid '
              'instructions and improving feature functionality in '
              'accordance with our Privacy Policy.',
        ],
      ),
      TermsSection(
        header: 'Health Journal & Progress Tracking',
        subheader: true,
        bullets: [
          'Purpose and Usage: The Health Journal is a personalized tracking '
              'tool designed to allow users to document, monitor, and '
              'visualize their healing progress over time.',
          'User Responsibility: Information logged in the Health Journal is '
              'self-reported. Users are solely responsible for the accuracy '
              'of entries made within their personal journals.',
        ],
      ),
      TermsSection(
        header: 'ACCEPTABLE USE POLICY',
        paragraph: 'You agree not to:',
        bullets: [
          'Use the App for any unlawful, illegal, or fraudulent purpose.',
          'Impersonate any person or entity or misrepresent your '
              'affiliation or medical history.',
          'Attempt to reverse-engineer, decompile, hack, or compromise the '
              'security of the App.',
          'Introduce viruses, malware, or harmful code into the platform.',
          'Scrape, extract, or mine data from the App without prior written '
              'consent.',
        ],
      ),
      TermsSection(
        header: 'ADVISORY AND VALIDATION BY HEALTHCARE PROFESSIONALS',
        paragraph:
            'Fine Aid is created by a team of student developers who do not '
            'hold professional medical licenses. To enhance the accuracy, '
            'safety, and validity of the information offered:',
        bullets: [
          'First aid guides and general medical information within the App '
              'are reviewed, vetted, or referenced against standards '
              'validated by qualified healthcare professionals and '
              'recognized medical guidelines.',
          'Advice provided by the App remains informational and should '
              'always be verified with a certified healthcare practitioner '
              'when in doubt.',
        ],
      ),
      TermsSection(
        header: 'PRIVACY AND HEALTH DATA',
        paragraph:
            'Your privacy is critically important to us. Our collection, '
            'processing, and protection of personal health data and personal '
            'information are governed by our Privacy Policy, which is '
            'incorporated into these Terms by reference.',
        bullets: [
          'Consent: By using the App, you consent to the processing of your '
              'personal health data to facilitate first aid recommendations, '
              'tracking features, and related App services.',
          'Compliance: We comply with applicable data protection '
              'legislation (such as the Data Privacy Act of 2012, HIPAA, or '
              'GDPR where applicable).',
        ],
      ),
      TermsSection(
        header: 'LIMITATION OF LIABILITY & DISCLAIMER OF WARRANTIES',
      ),
      TermsSection(
        header: 'Limitation of Damages',
        subheader: true,
        warning: true,
        paragraph:
            'TO THE FULLEST EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT '
            'SHALL THE FINE AID DEV TEAM BE LIABLE FOR ANY INDIRECT, '
            'INCIDENTAL, CONSEQUENTIAL, SPECIAL, OR PUNITIVE DAMAGES ARISING '
            'OUT OF OR IN CONNECTION WITH YOUR USE OF THE APP OR RELIANCE ON '
            'ANY MEDICAL CONTENT, AI CAMERA GUIDANCE, OR SERVICES PROVIDED '
            'WITHIN THE APP.',
      ),
      TermsSection(
        header: 'TERMINATION',
        paragraph:
            'We reserve the right to suspend or terminate your account or '
            'access to the App at our sole discretion, without notice, if you '
            'violate these Terms, engage in fraudulent behavior, or misuse '
            'the App.',
      ),
      TermsSection(
        header: 'CHANGES TO THESE TERMS',
        paragraph:
            'We reserve the right to update or modify these Terms at any '
            'time. We will notify users of material updates via in-app '
            'notifications or email. Your continued use of the App following '
            'any changes constitutes acceptance of the new terms.',
      ),
    ],
  );

  static const tl = TermsStrings(
    title: 'Mga Tuntunin at Kundisyon',
    scrollHint: 'Mag-scroll hanggang dulo para makapagpatuloy.',
    agree: 'Sumasang-ayon Ako at Magpatuloy',
    saveError: 'Hindi na-save ang iyong pagsang-ayon. Pakisubukang muli.',
    sections: [
      TermsSection(
        header: '',
        paragraph:
            'Pakibasa nang mabuti ang Mga Tuntunin at Kundisyong ito bago '
            'gamitin ang App. Sa pag-download, pag-access, o paggamit ng Fine '
            'Aid, sumasang-ayon kang susundin mo ang mga Tuntuning ito. Kung '
            'hindi ka sumasang-ayon sa lahat ng Tuntuning ito, huwag gamitin '
            'o i-access ang App.',
      ),
      TermsSection(
        header: 'PAUNAWANG MEDIKAL AT MGA SERBISYONG PANG-EMERHENSIYA',
      ),
      TermsSection(
        header: 'HINDI PARA SA MGA EMERHENSIYA',
        subheader: true,
        warning: true,
        paragraph:
            'ANG APP AY HINDI PARA SA MGA MEDIKAL NA EMERHENSIYA. KUNG IKAW AY '
            'NAKARARANAS NG MEDIKAL NA EMERHENSIYA, KONDISYONG NANGANGANIB ANG '
            'BUHAY, O MALULUBHANG SINTOMAS, TUMAWAG AGAD SA IYONG LOKAL NA '
            'MGA SERBISYONG PANG-EMERHENSIYA (HAL., 911 O ANG IYONG LOKAL NA '
            'NUMERO PARA SA EMERHENSIYA) O PUMUNTA SA PINAKAMALAPIT NA '
            'EMERGENCY ROOM NG OSPITAL.',
      ),
      TermsSection(
        header: 'HINDI PAMALIT SA PROPESYONAL NA KONSULTASYONG MEDIKAL',
        subheader: true,
        paragraph:
            'Ang Fine Aid ay binuo ng mga student developer para sa suportang '
            'pang-edukasyon at pang-impormasyon lamang. Bagama’t ang mga '
            'protocol at nilalaman ng first aid sa App ay inihanda batay sa '
            'mga itinatag na alituntunin at pinagtibay ng mga lisensyadong '
            'medikal na practitioner, ang App ay hindi isang lisensyadong '
            'medical device, software as a medical device (SaMD), o kapalit ng '
            'propesyonal na payong medikal, klinikal na pagsusuri, o '
            'paggamot.\n\n'
            'Huwag kailanman balewalain, ipagpaliban, o iwasan ang paghingi '
            'ng propesyonal na payo o paggamot sa medisina. Kung pinaghihinalaan '
            'mong may kondisyong medikal, impeksyon, o malubhang pinsala ka, '
            'laging kumonsulta sa kuwalipikadong propesyonal sa kalusugan.',
      ),
      TermsSection(
        header: 'WALANG UGNAYANG DOKTOR–PASYENTE',
        subheader: true,
        paragraph:
            'Ang paggamit ng mga pangkalahatang tampok ng App ay hindi '
            'lumilikha ng ugnayang doktor-pasyente. Ang propesyonal na '
            'ugnayan ay nabubuo lamang sa pagitan mo at ng isang tiyak na '
            'kuwalipikadong tagapagbigay ng pangangalagang pangkalusugan sa '
            'isang pormal na konsultasyong pangkalusugan sa labas ng App na '
            'ito.',
      ),
      TermsSection(header: 'PAGGAMIT NG APP AT MGA TUNTUNIN SA ACCOUNT'),
      TermsSection(
        header: 'Kwalipikasyon',
        subheader: true,
        paragraph:
            'Dapat ay hindi bababa sa 18 taong gulang ka (o ang edad ng '
            'mayorya sa iyong nasasakupan) para magamit ang App nang mag-isa. '
            'Ang mga menor de edad ay maaari lamang gumamit ng App sa ilalim '
            'ng pangangasiwa ng magulang o legal na tagapag-alaga.',
      ),
      TermsSection(
        header: 'Pagpaparehistro at Seguridad ng Account',
        subheader: true,
        bullets: [
          'Dapat kang magbigay ng tumpak, napapanahon, at kumpletong '
              'impormasyon sa pagpaparehistro.',
          'Responsibilidad mong panatilihing kumpidensyal ang iyong mga '
              'kredensyal sa pag-log in (kabilang ang Username, Password, '
              'One-Time Password (OTP), at Email Address).',
          'Sumasang-ayon kang ipaalam sa amin agad ang anumang hindi awtorisadong '
              'paggamit o paglabag sa seguridad ng iyong account.',
        ],
      ),
      TermsSection(
        header: 'Tampok na AI Camera at Mga Pahintulot',
        subheader: true,
        bullets: [
          'Layunin at Paggamit: Kailangan ng App ang access sa camera ng '
              'iyong device para kumuha ng mga larawan ng mababaw na pinsala '
              'o sugat. Sinusuri ng isinamang AI model ang mga larawang ito '
              'para makabuo ng agaran at hakbang-hakbang na gabay at mungkahi '
              'sa first aid.',
          'Mga Limitasyon: Ang AI Camera ay awtomatikong kasangkapan sa '
              'paggabay at hindi nito kayang mag-diagnose ng mga kondisyong '
              'medikal, impeksyon, o malalim na trauma. Laging kumonsulta sa '
              'kuwalipikadong propesyonal sa kalusugan para sa wastong '
              'klinikal na pagsusuri.',
          'Pagsang-ayon: Sa pag-enable ng pahintulot sa camera, pumapayag ka '
              'sa pagproseso ng mga nakuhang larawan para lamang sa pagbibigay '
              'ng tagubilin sa first aid at pagpapabuti ng paggana ng tampok, '
              'alinsunod sa aming Patakaran sa Privacy.',
        ],
      ),
      TermsSection(
        header: 'Health Journal at Pagsubaybay ng Progreso',
        subheader: true,
        bullets: [
          'Layunin at Paggamit: Ang Health Journal ay personalisadong '
              'kasangkapan sa pagsubaybay na nagbibigay-daan sa mga user na '
              'itala, subaybayan, at makita ang kanilang progreso ng paggaling '
              'sa paglipas ng panahon.',
          'Responsibilidad ng User: Ang impormasyong itinatala sa Health '
              'Journal ay ikaw mismo ang nag-ulat. Ang mga user lamang ang '
              'responsable sa katumpakan ng mga entry sa kanilang personal na '
              'journal.',
        ],
      ),
      TermsSection(
        header: 'PATAKARAN SA WASTONG PAGGAMIT',
        paragraph: 'Sumasang-ayon kang hindi mo gagawin ang mga sumusunod:',
        bullets: [
          'Gamitin ang App para sa anumang labag sa batas, ilegal, o '
              'mapanlinlang na layunin.',
          'Magpanggap bilang ibang tao o entidad o magbigay ng maling '
              'impormasyon tungkol sa iyong kaugnayan o kasaysayang medikal.',
          'Tangkaing i-reverse-engineer, i-decompile, i-hack, o ikompromiso '
              'ang seguridad ng App.',
          'Magpasok ng virus, malware, o mapaminsalang code sa platform.',
          'Mag-scrape, kumuha, o mag-mina ng datos mula sa App nang walang '
              'paunang nakasulat na pahintulot.',
        ],
      ),
      TermsSection(
        header: 'PAYO AT BERIPIKASYON NG MGA PROPESYONAL SA KALUSUGAN',
        paragraph:
            'Ang Fine Aid ay nilikha ng isang pangkat ng mga student developer '
            'na walang propesyonal na lisensyang medikal. Upang mapahusay ang '
            'katumpakan, kaligtasan, at bisa ng impormasyong iniaalok:',
        bullets: [
          'Ang mga gabay sa first aid at pangkalahatang impormasyong medikal '
              'sa App ay sinusuri, pinagtitibay, o inihahambing sa mga '
              'pamantayang pinagtibay ng mga kuwalipikadong propesyonal sa '
              'kalusugan at kinikilalang alituntuning medikal.',
          'Ang payong ibinibigay ng App ay nananatiling impormasyon lamang at '
              'dapat laging ikumpirma sa sertipikadong practitioner sa '
              'kalusugan kapag may alinlangan.',
        ],
      ),
      TermsSection(
        header: 'PRIVACY AT DATOS SA KALUSUGAN',
        paragraph:
            'Napakahalaga sa amin ng iyong privacy. Ang aming pangongolekta, '
            'pagproseso, at proteksyon ng personal na datos sa kalusugan at '
            'personal na impormasyon ay sakop ng aming Patakaran sa Privacy, '
            'na isinasama sa mga Tuntuning ito bilang sanggunian.',
        bullets: [
          'Pagsang-ayon: Sa paggamit ng App, pumapayag ka sa pagproseso ng '
              'iyong personal na datos sa kalusugan para maisakatuparan ang '
              'mga rekomendasyon sa first aid, mga tampok sa pagsubaybay, at '
              'mga kaugnay na serbisyo ng App.',
          'Pagsunod: Sumusunod kami sa mga umiiral na batas sa proteksyon ng '
              'datos (tulad ng Data Privacy Act of 2012, HIPAA, o GDPR kung '
              'naaangkop).',
        ],
      ),
      TermsSection(
        header: 'LIMITASYON NG PANANAGUTAN AT DISCLAIMER NG MGA WARRANTY',
      ),
      TermsSection(
        header: 'Limitasyon ng mga Pinsala',
        subheader: true,
        warning: true,
        paragraph:
            'SA PINAKAMALAWAK NA SAKLAW NA PINAPAYAGAN NG UMIIRAL NA BATAS, SA '
            'ANUMANG PAGKAKATAON AY HINDI MANANAGOT ANG FINE AID DEV TEAM SA '
            'ANUMANG HINDI DIREKTA, KASABAY, KINAHINATNAN, ESPESYAL, O '
            'PARUSANG PINSALA NA LUMITAW MULA SA O KAUGNAY NG IYONG PAGGAMIT '
            'NG APP O PAGTITIWALA SA ANUMANG NILALAMANG MEDIKAL, GABAY NG AI '
            'CAMERA, O MGA SERBISYONG IBINIBIGAY SA LOOB NG APP.',
      ),
      TermsSection(
        header: 'PAGWAWAKAS',
        paragraph:
            'Inilalaan namin ang karapatang suspindihin o wakasan ang iyong '
            'account o access sa App ayon sa aming sariling pagpapasya, nang '
            'walang abiso, kung lalabagin mo ang mga Tuntuning ito, '
            'gagawa ng mapanlinlang na gawain, o aabusuhin ang App.',
      ),
      TermsSection(
        header: 'MGA PAGBABAGO SA MGA TUNTUNING ITO',
        paragraph:
            'Inilalaan namin ang karapatang i-update o baguhin ang mga '
            'Tuntuning ito anumang oras. Aabisuhan namin ang mga user tungkol '
            'sa mahahalagang pagbabago sa pamamagitan ng in-app na '
            'notification o email. Ang patuloy mong paggamit ng App pagkatapos '
            'ng anumang pagbabago ay nangangahulugan ng pagtanggap sa mga '
            'bagong tuntunin.',
      ),
    ],
  );
}
