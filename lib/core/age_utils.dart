/// The age at which a user is treated as an adult in Fine Aid.
const int kAdultAge = 18;

/// The age from which someone can use Fine Aid on their own. Under it, a
/// parent or guardian is asked to help set things up (a notice at sign-up; the
/// person can still carry on).
const int kIndependentAge = 16;

/// Whole years between [dateOfBirth] and [today] (defaults to now): the age
/// goes up on the birthday, not before. Never negative.
int calculateAge(DateTime dateOfBirth, {DateTime? today}) {
  final now = today ?? DateTime.now();
  var age = now.year - dateOfBirth.year;
  final hadBirthdayThisYear =
      now.month > dateOfBirth.month ||
      (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);
  if (!hadBirthdayThisYear) age--;
  return age < 0 ? 0 : age;
}
