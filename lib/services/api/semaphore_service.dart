import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../core/constants/api_keys.dart';

class SemaphoreService {
  static final SemaphoreService _instance = SemaphoreService._internal();
  factory SemaphoreService() => _instance;
  SemaphoreService._internal();

  static const String _baseUrl = 'https://api.semaphore.co/api/v4';
  static const String _senderName = 'FINEAID';

  String _generateCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  String _formatNumber(String phoneNumber) {
    if (phoneNumber.startsWith('+63')) {
      return '0${phoneNumber.substring(3)}';
    }
    if (phoneNumber.startsWith('09')) {
      return phoneNumber;
    }
    if (phoneNumber.startsWith('9') && phoneNumber.length == 10) {
      return '0$phoneNumber';
    }
    return phoneNumber;
  }

  Future<bool> sendOtp({required String phoneNumber}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('SemaphoreService: no user logged in');
        return false;
      }

      final code = _generateCode();
      final formattedNumber = _formatNumber(phoneNumber);

      debugPrint(
        'SemaphoreService: sending OTP $code to '
        '$formattedNumber',
      );

      await FirebaseFirestore.instance
          .collection('otpVerifications')
          .doc(user.uid)
          .set({
            'code': code,
            'phoneNumber': formattedNumber,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(
              DateTime.now().add(const Duration(minutes: 10)),
            ),
            'verified': false,
            'attempts': 0,
          });

      debugPrint('SemaphoreService: OTP stored in Firestore');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/otp'),
            body: {
              'apikey': ApiKeys.semaphore,
              'number': formattedNumber,
              'message':
                  'Your Fine Aid OTP code is {otp}. '
                  'Valid for 10 minutes. '
                  'Do not share this code.',
              'code': code,
              'sendername': _senderName,
            },
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
        'SemaphoreService: response status '
        '${response.statusCode}',
      );
      debugPrint(
        'SemaphoreService: response body '
        '${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('SemaphoreService: parsed $data');

        if (data is List && data.isNotEmpty) {
          final status = data[0]['status']?.toString().toLowerCase();
          debugPrint('SemaphoreService: status=$status');
          // Semaphore statuses: Pending, Queued, Sent
          if (status == 'pending' || status == 'queued' || status == 'sent') {
            debugPrint('SemaphoreService: SMS queued ✓');
            return true;
          }
        }

        if (data is Map) {
          debugPrint('SemaphoreService: map response $data');
          return true;
        }
      }

      if (response.statusCode == 403) {
        debugPrint(
          'SemaphoreService: invalid API key or '
          'insufficient credits',
        );
      } else if (response.statusCode == 400) {
        debugPrint(
          'SemaphoreService: bad request — check '
          'phone number format',
        );
      }

      return false;
    } catch (e) {
      debugPrint('SemaphoreService sendOtp error: $e');
      return false;
    }
  }

  Future<OtpVerificationResult> verifyOtp({required String code}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return OtpVerificationResult.error;

      final doc = await FirebaseFirestore.instance
          .collection('otpVerifications')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        debugPrint('SemaphoreService: no OTP doc found for user');
        return OtpVerificationResult.notFound;
      }

      final data = doc.data()!;
      final attempts = data['attempts'] as int? ?? 0;

      debugPrint(
        'SemaphoreService: verifying code=$code, '
        'attempts=$attempts',
      );

      if (attempts >= 5) {
        debugPrint('SemaphoreService: too many attempts');
        return OtpVerificationResult.tooManyAttempts;
      }

      final expiresAt = data['expiresAt'] as Timestamp?;
      if (expiresAt != null && DateTime.now().isAfter(expiresAt.toDate())) {
        debugPrint('SemaphoreService: OTP expired');
        return OtpVerificationResult.expired;
      }

      await FirebaseFirestore.instance
          .collection('otpVerifications')
          .doc(user.uid)
          .update({'attempts': FieldValue.increment(1)});

      final storedCode = data['code'] as String?;
      debugPrint(
        'SemaphoreService: stored=$storedCode, '
        'entered=$code',
      );

      if (storedCode != code.trim()) {
        debugPrint('SemaphoreService: code mismatch');
        return OtpVerificationResult.invalid;
      }

      await FirebaseFirestore.instance
          .collection('otpVerifications')
          .doc(user.uid)
          .update({'verified': true});

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'phoneVerified': true},
      );

      debugPrint('SemaphoreService: verification success ✓');
      return OtpVerificationResult.success;
    } catch (e) {
      debugPrint('SemaphoreService verifyOtp error: $e');
      return OtpVerificationResult.error;
    }
  }

  Future<void> clearOtp() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('otpVerifications')
          .doc(user.uid)
          .delete();
    } catch (e) {
      debugPrint('SemaphoreService clearOtp error: $e');
    }
  }
}

enum OtpVerificationResult {
  success,
  invalid,
  expired,
  notFound,
  tooManyAttempts,
  error,
}
