import 'dart:convert';

import 'package:fine_aid/features/admin/admin_security_settings.dart';
import 'package:fine_aid/features/admin/screens/widgets/admin_audit_pdf.dart';
import 'package:fine_aid/features/admin/screens/widgets/admin_audit_text.dart';
import 'package:fine_aid/services/firebase/login_lockout_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('plain-language audit text', () {
    test('reads as a sentence, naming who did what', () {
      expect(
        describeAudit({'action': 'Admin signed in'}, 'maria'),
        "'maria' signed in to the admin portal",
      );
      expect(
        describeAudit({
          'action': 'Failed login lockout turned on (5 attempts, 15 minutes)',
        }, 'maria'),
        contains('locked for 15 minutes after 5 wrong passwords'),
      );
      expect(
        describeAudit({
          'action': 'Edited user Maria Santos',
          'targetName': 'Maria Santos',
          'reason': 'fields:firstName,phoneNumber',
        }, 'maria'),
        "'maria' edited the profile of 'Maria Santos' "
        '(changed: first name, phone number)',
      );
    });

    test('never leaves a raw id, code or technical string in the sentence', () {
      const uid =
          'aB3dE5gH7jK9mN1pQ3sT5vX7zC9e'; // 28 chars, like a sign-in uid
      const docId = 'Q7wE3rT5yU9iO1pA4sD6'; // 20 chars, like a document id
      for (final action in [
        'Resolved feedback $docId',
        'Edited user $uid',
        'Cancelled scheduled deactivation: $uid',
        'Something unusual happened to $docId ($uid)',
      ]) {
        final text = describeAudit({'action': action}, 'maria');
        expect(text, isNot(contains(uid)), reason: action);
        expect(text, isNot(contains(docId)), reason: action);
        expect(text, isNot(contains('()')), reason: action);
      }
    });

    test('an unknown action keeps its wording', () {
      expect(
        describeAudit({'action': 'Rotated the moon'}, 'maria'),
        "'maria': rotated the moon",
      );
    });

    test('the system is named as "The system" when there is no actor', () {
      expect(
        describeAudit({'action': 'Admin signed in'}, 'System'),
        startsWith('The system'),
      );
    });

    test('the Action column is a plain word, not a code', () {
      expect(auditActionLabel({'type': 'CREATE'}), 'Created');
      expect(auditActionLabel({'type': 'DELETE'}), 'Deleted');
      expect(auditActionLabel({'type': 'UPDATE'}), 'Updated');
      expect(auditActionLabel({}), 'Updated');
      expect(
        auditActionLabel({'type': 'LOGIN', 'action': 'Admin signed in'}),
        'Signed in',
      );
      expect(
        auditActionLabel({
          'type': 'LOGIN',
          'action': 'Failed admin sign-in attempt',
        }),
        'Sign-in refused',
      );
      expect(
        auditActionLabel({
          'type': 'LOGIN',
          'action': 'Signed out automatically after inactivity',
        }),
        'Signed out',
      );
    });
  });

  group('audit PDF', () {
    test('is a real PDF with the entries in it', () async {
      final bytes = await buildAuditLogPdf(
        rows: [
          ['Oct 25, 2026 9:00 AM', "'maria' signed in", 'maria', 'Signed in'],
          for (var i = 0; i < 120; i++)
            ['Oct 24, 2026 9:00 AM', 'Entry number $i', 'maria', 'Updated'],
        ],
        generatedAt: DateTime(2026, 10, 25, 10),
        generatedBy: 'maria',
        truncated: true,
      );
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });

    test('copes with an empty log and with non-latin text', () async {
      final bytes = await buildAuditLogPdf(
        rows: [
          ['Oct 25, 2026', 'Ñandú – “quoted” 日本語', 'maría', 'Updated'],
        ],
        generatedAt: DateTime(2026, 10, 25),
        generatedBy: 'maría',
      );
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      final empty = await buildAuditLogPdf(
        rows: const [],
        generatedAt: DateTime(2026, 10, 25),
        generatedBy: 'maria',
      );
      expect(ascii.decode(empty.sublist(0, 5)), '%PDF-');
    });
  });

  group('failed-login lockout setting', () {
    test('defaults are on, 5 wrong passwords, 15 minutes', () {
      const c = LoginLockoutConfig.defaults;
      expect((c.enabled, c.maxAttempts, c.minutes), (true, 5, 15));
    });

    test('reads the admin setting', () {
      final c = LoginLockoutConfig.fromData({
        'lockoutEnabled': true,
        'lockoutMaxAttempts': 3,
        'lockoutMinutes': 60,
      });
      expect(c.maxAttempts, 3);
      expect(c.lockDuration, const Duration(minutes: 60));
      expect(c.shouldLock(2), isFalse);
      expect(c.shouldLock(3), isTrue);
    });

    test('off means never lock', () {
      final c = LoginLockoutConfig.fromData({'lockoutEnabled': false});
      expect(c.shouldLock(1000), isFalse);
    });

    test(
      'missing, wrong-typed or unlisted values fall back to the defaults',
      () {
        for (final data in <Map<String, dynamic>?>[
          null,
          {},
          {
            'lockoutEnabled': 'yes',
            'lockoutMaxAttempts': 4,
            'lockoutMinutes': 7.5,
          },
        ]) {
          final c = LoginLockoutConfig.fromData(data);
          expect((c.enabled, c.maxAttempts, c.minutes), (true, 5, 15));
        }
      },
    );

    test('the admin settings model carries the same values', () {
      final s = AdminSecuritySettings.fromData({
        'idleTimeoutEnabled': false,
        'idleTimeoutMinutes': 30,
        'lockoutEnabled': false,
        'lockoutMaxAttempts': 10,
        'lockoutMinutes': 5,
      });
      expect(s.idleTimeoutEnabled, isFalse);
      expect(s.idleTimeoutMinutes, 30);
      expect(s.lockoutEnabled, isFalse);
      expect(s.lockoutMaxAttempts, 10);
      expect(s.lockoutMinutes, 5);
      expect(
        AdminSecuritySettings.fromData(null),
        AdminSecuritySettings.defaults,
      );
      expect(
        AdminSecuritySettings.fromData({
          'idleTimeoutMinutes': 999,
        }).idleTimeoutMinutes,
        AdminSecuritySettings.defaults.idleTimeoutMinutes,
      );
    });
  });
}
