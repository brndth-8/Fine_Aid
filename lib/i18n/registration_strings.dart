import 'package:flutter/widgets.dart';
import '../services/firebase/registration_flow.dart';
import 'app_language.dart';

/// Sign Up messages (English + Tagalog) for the text added or changed with
/// the all-or-nothing registration. Review the Tagalog before release.
class RegistrationStrings {
  final String usernameTaken;
  final String alreadyRegistered;
  final String emailTaken;
  final String network;
  final String timeout;
  final String weakPassword;
  final String tooManyRequests;
  final String saveFailed;
  final String unknown;
  final String firstNameLabel;
  final String lastNameLabel;
  final String dobLabel;
  final String ageLabel;
  final String genderLabel;
  final String firstNameHint;
  final String lastNameHint;
  final String dobHint;
  final String ageHint;
  final String genderHint;
  final String genderMale;
  final String genderFemale;
  final String genderOther;
  final String firstNameRequired;
  final String lastNameRequired;
  final String nameInvalid;
  final String dobRequired;
  final String dobFuture;
  final String dobInvalid;
  final String genderRequired;
  final String underageTitle;
  final String underageBody;
  final String underageButton;

  const RegistrationStrings({
    required this.usernameTaken,
    required this.alreadyRegistered,
    required this.emailTaken,
    required this.network,
    required this.timeout,
    required this.weakPassword,
    required this.tooManyRequests,
    required this.saveFailed,
    required this.unknown,
    required this.firstNameLabel,
    required this.lastNameLabel,
    required this.dobLabel,
    required this.ageLabel,
    required this.genderLabel,
    required this.firstNameHint,
    required this.lastNameHint,
    required this.dobHint,
    required this.ageHint,
    required this.genderHint,
    required this.genderMale,
    required this.genderFemale,
    required this.genderOther,
    required this.firstNameRequired,
    required this.lastNameRequired,
    required this.nameInvalid,
    required this.dobRequired,
    required this.dobFuture,
    required this.dobInvalid,
    required this.genderRequired,
    required this.underageTitle,
    required this.underageBody,
    required this.underageButton,
  });

  static RegistrationStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  String messageFor(RegistrationError error) => switch (error) {
    RegistrationError.usernameTaken => usernameTaken,
    RegistrationError.alreadyRegistered => alreadyRegistered,
    RegistrationError.emailTaken => emailTaken,
    RegistrationError.network => network,
    RegistrationError.timeout => timeout,
    RegistrationError.weakPassword => weakPassword,
    RegistrationError.tooManyRequests => tooManyRequests,
    RegistrationError.saveFailed => saveFailed,
    RegistrationError.unknown => unknown,
  };

  static const en = RegistrationStrings(
    usernameTaken: 'This username is already taken. Please choose another one.',
    alreadyRegistered:
        'This username is already registered. If you started signing up with '
        'it earlier, enter the same password you used then to continue. '
        'Otherwise, choose another username.',
    emailTaken: 'This email is already registered.',
    network:
        'No internet connection. Nothing was saved. Please check your '
        'connection and try again.',
    timeout:
        'The connection is too slow and sign-up took too long. Please check '
        'your internet connection and try again.',
    weakPassword: 'Password is too weak.',
    tooManyRequests: 'Too many attempts. Please wait a moment and try again.',
    saveFailed:
        'We could not save your account. Nothing was created. Please try '
        'again.',
    unknown: 'Registration failed. Please try again.',
    firstNameLabel: 'First Name',
    lastNameLabel: 'Last Name',
    dobLabel: 'Date of Birth',
    ageLabel: 'Age',
    genderLabel: 'Gender',
    firstNameHint: 'Enter your first name',
    lastNameHint: 'Enter your last name',
    dobHint: 'MM/DD/YYYY',
    ageHint: 'Calculated from your date of birth',
    genderHint: 'Select gender',
    genderMale: 'Male',
    genderFemale: 'Female',
    genderOther: 'Other / Prefer not to say',
    firstNameRequired: 'First name is required',
    lastNameRequired: 'Last name is required',
    nameInvalid:
        'Only letters, spaces, hyphens, apostrophes and periods allowed',
    dobRequired: 'Date of birth is required',
    dobFuture: 'Date of birth can\'t be in the future',
    dobInvalid: 'Please enter a valid date of birth',
    genderRequired: 'Please select a gender',
    underageTitle: 'Underage Access & Supervision Disclaimer',
    underageBody:
        'Notice: Users under the age of 18 must access and operate Fine Aid under the active supervision of a parent or lawful guardian.\n\nWhile Fine Aid offers evidence-based first-aid protocols, users under 18 should always consult an adult guardian or licensed medical professional before performing any first-aid intervention or health decision.',
    underageButton: 'I Acknowledge & Proceed',
  );

  static const tl = RegistrationStrings(
    usernameTaken: 'Gamit na ang username na ito. Pumili ng ibang username.',
    alreadyRegistered:
        'Rehistrado na ang username na ito. Kung sinimulan mo na itong '
        'gamitin sa pag-sign up kanina, ilagay ang parehong password na '
        'ginamit mo para magpatuloy. Kung hindi, pumili ng ibang username.',
    emailTaken: 'Nakarehistro na ang email na ito.',
    network:
        'Walang koneksyon sa internet. Walang nai-save. Pakisuri ang iyong '
        'koneksyon at subukang muli.',
    timeout:
        'Mabagal ang koneksyon kaya natagalan ang pag-sign up. Pakisuri ang '
        'iyong internet at subukang muli.',
    weakPassword: 'Masyadong mahina ang password.',
    tooManyRequests:
        'Masyadong maraming pagsubok. Maghintay sandali at subukang muli.',
    saveFailed:
        'Hindi namin ma-save ang iyong account. Walang nagawang account. '
        'Pakisubukang muli.',
    unknown: 'Hindi natuloy ang pagrehistro. Pakisubukang muli.',
    firstNameLabel: 'Pangalan',
    lastNameLabel: 'Apelyido',
    dobLabel: 'Petsa ng Kapanganakan',
    ageLabel: 'Edad',
    genderLabel: 'Kasarian',
    firstNameHint: 'Ilagay ang iyong pangalan',
    lastNameHint: 'Ilagay ang iyong apelyido',
    dobHint: 'MM/DD/YYYY',
    ageHint: 'Kinukuwenta mula sa petsa ng iyong kapanganakan',
    genderHint: 'Piliin ang kasarian',
    genderMale: 'Lalaki',
    genderFemale: 'Babae',
    genderOther: 'Iba pa / Ayokong sabihin',
    firstNameRequired: 'Kailangan ang pangalan',
    lastNameRequired: 'Kailangan ang apelyido',
    nameInvalid:
        'Letra, espasyo, gitling, kudlit at tuldok lamang ang pinapayagan',
    dobRequired: 'Kailangan ang petsa ng kapanganakan',
    dobFuture: 'Hindi maaaring nasa hinaharap ang petsa ng kapanganakan',
    dobInvalid: 'Maglagay ng wastong petsa ng kapanganakan',
    genderRequired: 'Pumili ng kasarian',
    underageTitle: 'Paunawa sa Pag-access at Pangangasiwa ng mga Menor de Edad',
    underageBody:
        'Paunawa: Ang mga gumagamit na wala pang 18 taong gulang ay dapat gumamit ng Fine Aid sa aktibong pangangasiwa ng magulang o legal na tagapag-alaga.\n\nBagaman nag-aalok ang Fine Aid ng mga protocol sa first aid na batay sa ebidensya, ang mga wala pang 18 taong gulang ay dapat laging sumangguni sa nasa hustong gulang na tagapag-alaga o lisensyadong propesyonal sa kalusugan bago gumawa ng anumang first aid o magdesisyon tungkol sa kalusugan.',
    underageButton: 'Kinikilala Ko at Magpapatuloy',
  );
}
