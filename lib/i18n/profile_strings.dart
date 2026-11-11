import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text for the Profile screen, English + Tagalog. Review the Tagalog before
/// release.
class ProfileStrings {
  final String title;
  final String accountProfile;
  final String accountDetails;
  final String fullName;
  final String username;
  final String phone;
  final String email;
  final String birthday;
  final String gender;
  final String healthProfile;
  final String conditions;
  final String medications;
  final String none;
  final String notSet;
  final String notProvided;
  final String edit;
  final String update;
  final String notSignedIn;
  // The Profile a guest sees: a lock with a way to sign up or log in.
  final String unlockTitle;
  final String unlockBody;
  final String signUp;
  final String haveAccountLogIn;

  const ProfileStrings({
    required this.title,
    required this.accountProfile,
    required this.accountDetails,
    required this.fullName,
    required this.username,
    required this.phone,
    required this.email,
    required this.birthday,
    required this.gender,
    required this.healthProfile,
    required this.conditions,
    required this.medications,
    required this.none,
    required this.notSet,
    required this.notProvided,
    required this.edit,
    required this.update,
    required this.notSignedIn,
    required this.unlockTitle,
    required this.unlockBody,
    required this.signUp,
    required this.haveAccountLogIn,
  });

  static ProfileStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = ProfileStrings(
    title: 'Profile',
    accountProfile: 'Account Profile',
    accountDetails: 'Account Details',
    fullName: 'Full Name',
    username: 'Username',
    phone: 'Phone number',
    email: 'Email Address',
    birthday: 'Birthday',
    gender: 'Gender',
    healthProfile: 'Health Profile',
    conditions: 'Health conditions',
    medications: 'Medications',
    none: 'None',
    notSet: 'Not set yet',
    notProvided: 'Not provided',
    edit: 'Edit',
    update: 'Update',
    notSignedIn: 'Not signed in',
    unlockTitle: 'Unlock Your Profile',
    unlockBody: 'A personalized profile is available for registered members.',
    signUp: 'Sign Up',
    haveAccountLogIn: 'Already have an account? Log In here',
  );

  static const tl = ProfileStrings(
    title: 'Profile',
    accountProfile: 'Profile ng Account',
    accountDetails: 'Mga Detalye ng Account',
    fullName: 'Buong Pangalan',
    username: 'Username',
    phone: 'Numero ng telepono',
    email: 'Email Address',
    birthday: 'Kaarawan',
    gender: 'Kasarian',
    healthProfile: 'Profile ng Kalusugan',
    conditions: 'Mga kondisyon sa kalusugan',
    medications: 'Mga gamot',
    none: 'Wala',
    notSet: 'Hindi pa naitatakda',
    notProvided: 'Hindi naibigay',
    edit: 'I-edit',
    update: 'I-update',
    notSignedIn: 'Hindi naka-sign in',
    unlockTitle: 'I-unlock ang Iyong Profile',
    unlockBody:
        'May personalized na profile para sa mga rehistradong miyembro.',
    signUp: 'Mag-sign Up',
    haveAccountLogIn: 'May account ka na? Mag-log In dito',
  );
}
