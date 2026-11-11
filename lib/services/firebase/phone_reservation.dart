import 'package:cloud_firestore/cloud_firestore.dart';

/// Philippine mobile numbers are compared and stored as `+639XXXXXXXXX`, so
/// "09171234567", "9171234567" and "+63 917 123 4567" are the same number.
/// Returns null when [raw] isn't a 10-digit mobile number after the country
/// code / leading 0 is removed (9XXXXXXXXX, or an 08 number).
String? normalizePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  String? national;
  if (digits.length == 12 && digits.startsWith('63')) {
    national = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    national = digits.substring(1);
  } else if (digits.length == 10) {
    national = digits;
  }
  // 09 numbers, and the 08 ones (0811, 0813, 0817, 0895-0898).
  if (national == null ||
      !RegExp(r'^(9\d{9}|8(11|13|17|95|96|97|98)\d{7})$').hasMatch(national)) {
    return null;
  }
  return '+63$national';
}

/// The number is already reserved by a different account.
class PhoneTakenException implements Exception {
  const PhoneTakenException(this.phone);
  final String phone;

  @override
  String toString() => 'PhoneTakenException($phone)';
}

/// "One account per phone number", kept the same way as email (see
/// EmailReservation): a reservation document `phones/{+639XXXXXXXXX}` =
/// `{uid}`, written in the SAME transaction as the profile. Firestore rules
/// (see `phones` in firestore.rules) refuse a profile that sets or changes
/// `phoneNumber` without holding its reservation, so the server rejects
/// duplicates even if the app's own check is skipped.
class PhoneReservation {
  PhoneReservation._();

  /// All the reads, which a transaction requires before any write. Throws
  /// [PhoneTakenException] if [newPhone] belongs to another account. Returns
  /// the writes to run afterwards: reserve [newPhone], and release [oldPhone]
  /// if this account held it.
  ///
  /// Either may be null/empty. An account that already owns [newPhone] (or
  /// never had a reservation) is fine.
  static Future<void Function()> prepare(
    Transaction tx,
    FirebaseFirestore firestore, {
    required String uid,
    String? newPhone,
    String? oldPhone,
  }) async {
    final next = (newPhone == null || newPhone.trim().isEmpty)
        ? null
        : normalizePhone(newPhone);
    final prev = (oldPhone == null || oldPhone.trim().isEmpty)
        ? null
        : normalizePhone(oldPhone);
    final col = firestore.collection('phones');

    DocumentSnapshot<Map<String, dynamic>>? nextSnap;
    DocumentSnapshot<Map<String, dynamic>>? prevSnap;
    if (next != null) {
      nextSnap = await tx.get(col.doc(next));
      if (nextSnap.exists && nextSnap.data()?['uid'] != uid) {
        throw PhoneTakenException(next);
      }
    }
    if (prev != null && prev != next) {
      prevSnap = await tx.get(col.doc(prev));
    }

    return () {
      if (next != null && nextSnap != null && !nextSnap.exists) {
        tx.set(col.doc(next), {'uid': uid});
      }
      if (prev != null &&
          prevSnap != null &&
          prevSnap.exists &&
          prevSnap.data()?['uid'] == uid) {
        tx.delete(col.doc(prev));
      }
    };
  }
}
