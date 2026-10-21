import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fine_aid/features/admin/screens/widgets/admin_user_info.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> rowsFor(Map<String, dynamic> data) => {
  for (final (label, value) in adminUserInfoRows(
    data,
    today: DateTime(2026, 6, 1),
  ))
    label: value,
};

void main() {
  test('an older user with almost nothing stored shows N/A, never blanks', () {
    final rows = rowsFor({'username': 'old'});
    expect(rows['Username'], 'old');
    for (final key in [
      'First Name',
      'Last Name',
      'Email',
      'Phone number',
      'Date of Birth',
      'Age',
      'Gender',
      'Date created',
      'Last updated',
      'Underage acknowledgment',
    ]) {
      expect(rows[key], 'N/A', reason: key);
    }
    // Every stored profile is a registered account.
    expect(rows['Account type'], 'Registered');
  });

  test('a full profile shows every stored detail', () {
    final rows = rowsFor({
      'username': 'juan',
      'firstName': 'Juan',
      'lastName': 'Dela Cruz',
      'recoveryEmail': 'juan@example.com',
      'phoneNumber': '+639171234567',
      'dateOfBirth': Timestamp.fromDate(DateTime(2010, 3, 5)),
      'gender': 'male',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 2, 15, 30)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 2, 3, 9, 5)),
      'underageAcknowledged': true,
      'underageAcknowledgedAt': Timestamp.fromDate(
        DateTime(2026, 1, 2, 15, 29),
      ),
    });
    expect(rows['Email'], 'juan@example.com');
    expect(rows['Phone number'], '+639171234567');
    expect(rows['Age'], '16');
    expect(rows['Gender'], 'Male');
    expect(rows['Date created'], 'Jan 2, 2026 3:30 PM');
    expect(rows['Last updated'], 'Feb 3, 2026 9:05 AM');
    expect(
      rows['Underage acknowledgment'],
      'Acknowledged on Jan 2, 2026 3:29 PM',
    );
  });

  test('an acknowledgment with no timestamp still reads as acknowledged', () {
    final rows = rowsFor({'username': 'x', 'underageAcknowledged': true});
    expect(rows['Underage acknowledgment'], 'Acknowledged');
  });
}
