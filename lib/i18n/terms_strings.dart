import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// One block of the Terms & Conditions: a heading, then an optional
/// paragraph and/or a bullet list (in that order).
class TermsSection {
  final String header;
  final String? paragraph;
  final List<String> bullets;

  const TermsSection({
    required this.header,
    this.paragraph,
    this.bullets = const [],
  });
}

/// Terms & Conditions screen text (English + Tagalog). The English is the
/// original wording, unchanged. Tagalog is a plain-language translation and
/// should be reviewed before release, as this is legal/medical text.
class TermsStrings {
  final String title;
  final String scrollHint;
  final String agree;
  final String saveError;
  final List<TermsSection> sections;
  final String closing;

  const TermsStrings({
    required this.title,
    required this.scrollHint,
    required this.agree,
    required this.saveError,
    required this.sections,
    required this.closing,
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
        header: 'Medical Disclaimer',
        paragraph:
            'This application uses Artificial Intelligence (AI) to provide '
            'initial First Aid guidance only. It is not a diagnostic tool and '
            'does not provide a definitive medical opinion. Please read these '
            'carefully before using our mobile application and services.',
      ),
      TermsSection(
        header: '1. Acceptance of Terms',
        paragraph:
            'By downloading, installing, or using this App, you agree to be '
            'bound by these Terms.',
      ),
      TermsSection(
        header: '2. No Medical Advice Disclaimer',
        bullets: [
          'Information Only: All content provided within the App is '
              'for informational purposes only.',
          'No Doctor-Patient Relationship: Use of this App does not '
              'create a doctor-patient relationship.',
          'Consult Professionals: The App is not a substitute for '
              'professional medical advice or diagnosis. Always seek the '
              'advice of your physician or other qualified healthcare '
              'provider with any questions you may have regarding a '
              'medical condition.',
        ],
      ),
      TermsSection(
        header: '3. Emergency Disclaimer',
        bullets: [
          'Do Not Use for Emergencies: This App is NOT to be used for '
              'medical emergencies.',
          'Emergency Action: If you are experiencing a medical '
              'emergency, call emergency services or go to the nearest '
              'hospital emergency room immediately.',
        ],
      ),
      TermsSection(
        header: '4. Privacy and Data Security',
        bullets: [
          'Privacy Policy: Your use of the App is also governed by our '
              'Privacy Policy.',
          'Data Compliance: We handle data in accordance with '
              'applicable laws, including the Data Privacy Act of 2012 '
              '(Republic Act No. 10173) and other relevant health '
              'privacy regulations.',
        ],
      ),
      TermsSection(
        header: '5. Permitted Use and Restrictions',
        paragraph: 'You agree not to:',
        bullets: [
          'Use the App for any illegal purpose.',
          'Input false, misleading, or inaccurate health data.',
          "Attempt to hack, reverse-engineer, or disrupt the App's "
              'servers and networks.',
        ],
      ),
    ],
    closing:
        'By continuing, you agree to use this application as a guide '
        'only and assume all responsibility for any actions taken '
        'based on its content.',
  );

  static const tl = TermsStrings(
    title: 'Mga Tuntunin at Kundisyon',
    scrollHint: 'Mag-scroll hanggang dulo para makapagpatuloy.',
    agree: 'Sumasang-ayon Ako at Magpatuloy',
    saveError: 'Hindi na-save ang iyong pagsang-ayon. Pakisubukang muli.',
    sections: [
      TermsSection(
        header: 'Paunawang Medikal',
        paragraph:
            'Gumagamit ang application na ito ng Artificial Intelligence (AI) '
            'para magbigay lamang ng paunang gabay sa First Aid. Hindi ito '
            'kasangkapan sa pagsusuri (diagnosis) at hindi ito nagbibigay ng '
            'tiyak na opinyong medikal. Pakibasa nang mabuti ang mga ito bago '
            'gamitin ang aming mobile application at mga serbisyo.',
      ),
      TermsSection(
        header: '1. Pagtanggap sa mga Tuntunin',
        paragraph:
            'Sa pag-download, pag-install, o paggamit ng App na ito, '
            'sumasang-ayon kang susundin mo ang mga Tuntuning ito.',
      ),
      TermsSection(
        header: '2. Paunawa: Walang Payong Medikal',
        bullets: [
          'Impormasyon Lamang: Ang lahat ng nilalaman sa App ay '
              'para sa impormasyon lamang.',
          'Walang Ugnayang Doktor at Pasyente: Ang paggamit ng App na ito '
              'ay hindi lumilikha ng ugnayan ng doktor at pasyente.',
          'Kumonsulta sa mga Propesyonal: Hindi pamalit ang App sa payong '
              'medikal o pagsusuri ng isang propesyonal. Laging humingi ng '
              'payo sa iyong doktor o sa iba pang kuwalipikadong '
              'tagapagbigay ng pangangalagang pangkalusugan tungkol sa '
              'anumang tanong mo sa isang kondisyong medikal.',
        ],
      ),
      TermsSection(
        header: '3. Paunawa sa Emerhensiya',
        bullets: [
          'Huwag Gamitin sa Emerhensiya: HINDI dapat gamitin ang App na ito '
              'sa mga medikal na emerhensiya.',
          'Dapat Gawin sa Emerhensiya: Kung ikaw ay nasa isang medikal na '
              'emerhensiya, tumawag agad sa mga serbisyong pang-emerhensiya '
              'o pumunta sa pinakamalapit na emergency room ng ospital.',
        ],
      ),
      TermsSection(
        header: '4. Privacy at Seguridad ng Datos',
        bullets: [
          'Patakaran sa Privacy: Saklaw din ng aming Patakaran sa Privacy '
              'ang paggamit mo ng App.',
          'Pagsunod sa Batas sa Datos: Pinangangasiwaan namin ang datos '
              'alinsunod sa mga umiiral na batas, kabilang ang Data Privacy '
              'Act of 2012 (Republic Act No. 10173) at iba pang kaugnay na '
              'regulasyon sa privacy ng kalusugan.',
        ],
      ),
      TermsSection(
        header: '5. Pinahihintulutang Paggamit at mga Limitasyon',
        paragraph: 'Sumasang-ayon kang hindi mo gagawin ang mga sumusunod:',
        bullets: [
          'Gamitin ang App para sa anumang labag sa batas na layunin.',
          'Maglagay ng mali, nakaliligaw, o hindi tumpak na datos '
              'pangkalusugan.',
          'Tangkaing i-hack, i-reverse-engineer, o guluhin ang mga server '
              'at network ng App.',
        ],
      ),
    ],
    closing:
        'Sa pagpapatuloy, sumasang-ayon kang gamitin ang application na ito '
        'bilang gabay lamang at pananagutan mo ang anumang hakbang na '
        'gagawin batay sa nilalaman nito.',
  );
}
