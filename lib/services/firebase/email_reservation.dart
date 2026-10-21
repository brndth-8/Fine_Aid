import 'package:cloud_firestore/cloud_firestore.dart';

/// Emails are compared and stored trimmed and lower-case, so
/// "User@Email.com " and "user@email.com" are the same address.
String normalizeEmail(String raw) => raw.trim().toLowerCase();

/// The address is already reserved by a different account.
class EmailTakenException implements Exception {
  const EmailTakenException(this.email);
  final String email;

  @override
  String toString() => 'EmailTakenException($email)';
}

/// Firestore has no unique indexes, so "one account per email" is kept with
/// reservation documents: `emails/{normalizedEmail}` = `{uid}`. Writing the
/// reservation in the SAME transaction as the profile means two sign-ups can't
/// both win the same address, and Firestore rules (see `emails` in
/// firestore.rules) refuse a profile that sets or changes `recoveryEmail`
/// without holding its reservation — so the server rejects duplicates even if
/// the app's own check is skipped.
class EmailReservation {
  EmailReservation._();

  /// All the reads, which a transaction requires before any write. Throws
  /// [EmailTakenException] if [newEmail] belongs to another account. Returns
  /// the writes to run afterwards: reserve [newEmail], and release [oldEmail]
  /// if this account held it.
  ///
  /// Either may be null/empty (no email). An account that already owns
  /// [newEmail] (or never had a reservation) is fine.
  static Future<void Function()> prepare(
    Transaction tx,
    FirebaseFirestore firestore, {
    required String uid,
    String? newEmail,
    String? oldEmail,
  }) async {
    final next = (newEmail == null || newEmail.trim().isEmpty)
        ? null
        : normalizeEmail(newEmail);
    final prev = (oldEmail == null || oldEmail.trim().isEmpty)
        ? null
        : normalizeEmail(oldEmail);
    final col = firestore.collection('emails');

    DocumentSnapshot<Map<String, dynamic>>? nextSnap;
    DocumentSnapshot<Map<String, dynamic>>? prevSnap;
    if (next != null) {
      nextSnap = await tx.get(col.doc(next));
      if (nextSnap.exists && nextSnap.data()?['uid'] != uid) {
        throw EmailTakenException(next);
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
