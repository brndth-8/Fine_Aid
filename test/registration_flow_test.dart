import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'package:fine_aid/services/firebase/registration_flow.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for Firebase Auth + Firestore, with switches to make
/// each step fail the way the real one does.
class FakeBackend implements RegistrationBackend {
  // email -> (password, uid)
  final Map<String, ({String password, String uid})> auth = {};
  final Map<String, Map<String, Object?>> users = {};
  final Map<String, String> usernames = {}; // username -> uid
  final Map<String, String> emails = {}; // reserved email -> uid
  final Map<String, String> phones = {}; // reserved +63 number -> uid
  String? signedInUid;
  int _next = 1;

  bool offline = false;
  bool authHangsAfterCreating =
      false; // creates the account, then never answers
  bool claimHangsAfterCommit = false; // commits, then never answers
  bool claimFailsBeforeCommit = false; // times out without writing
  Object? claimThrows; // e.g. permission-denied
  bool claimLosesRace = false;
  bool goOfflineAfterCreate = false; // the connection drops right after Auth
  int createCalls = 0;

  FirebaseException get _unavailable =>
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

  void _requireOnline() {
    if (offline) {
      throw FirebaseAuthException(code: 'network-request-failed');
    }
  }

  @override
  Future<String?> usernameOwner(String username) async {
    if (offline) throw _unavailable;
    return usernames[username];
  }

  @override
  Future<String> createAuthUser(String email, String password) async {
    createCalls++;
    _requireOnline();
    if (auth.containsKey(email)) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    final uid = 'uid${_next++}';
    auth[email] = (password: password, uid: uid);
    signedInUid = uid;
    if (goOfflineAfterCreate) offline = true;
    if (authHangsAfterCreating) await Completer<void>().future;
    return uid;
  }

  @override
  Future<String> signIn(String email, String password) async {
    _requireOnline();
    final a = auth[email];
    if (a == null || a.password != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    signedInUid = a.uid;
    return a.uid;
  }

  @override
  Future<RegistrationProfile> readProfile(String uid) async {
    if (offline) throw _unavailable;
    final d = users[uid];
    return RegistrationProfile(
      exists: d != null,
      markedComplete: d?['registrationComplete'] == true,
      hasProgress:
          d?['phoneVerified'] == true || d?['onboardingComplete'] == true,
    );
  }

  @override
  Future<bool> claim({
    required String uid,
    required String username,
    required String email,
    required Map<String, Object?> profile,
  }) async {
    if (offline) throw _unavailable;
    if (claimThrows != null) throw claimThrows!;
    if (claimFailsBeforeCommit) await Completer<void>().future;
    if (claimLosesRace) return false;
    final owner = usernames[username];
    if (owner != null && owner != uid) return false;
    // Same rule as the real backend: the email is reserved in the same
    // transaction, and a different account's address is refused.
    final recovery = profile['recoveryEmail'] as String?;
    if (recovery != null) {
      final holder = emails[recovery];
      if (holder != null && holder != uid) {
        throw const RegistrationException(RegistrationError.emailTaken);
      }
      emails[recovery] = uid;
    }
    // And the phone number the same way: one account per number.
    final phone = profile['phoneNumber'] as String?;
    if (phone != null) {
      final holder = phones[phone];
      if (holder != null && holder != uid) {
        throw const RegistrationException(RegistrationError.phoneTaken);
      }
      phones[phone] = uid;
    }
    users[uid] = {...profile, 'registrationComplete': true};
    usernames[username] = uid;
    if (claimHangsAfterCommit) await Completer<void>().future;
    return true;
  }

  @override
  Future<void> deleteCurrentAuthUser() async {
    auth.removeWhere((_, a) => a.uid == signedInUid);
    signedInUid = null;
  }

  @override
  Future<void> signOut() async => signedInUid = null;

  // What the server's "free a ghost number" call does in these tests.
  final Set<String> ghostPhones = {}; // reservations held by a ghost
  final Set<String> ghostEmails = {};
  final List<String> releaseCalls = [];
  bool releaseFails = false;

  @override
  Future<bool> releaseStaleContact(String kind, String value) async {
    releaseCalls.add('$kind:$value');
    if (releaseFails) throw Exception('functions unavailable');
    if (kind == 'phone' && ghostPhones.remove(value)) {
      phones.remove(value);
      return true;
    }
    if (kind == 'email' && ghostEmails.remove(value)) {
      emails.remove(value);
      return true;
    }
    return false;
  }

  bool get hasNothing => auth.isEmpty && users.isEmpty && usernames.isEmpty;
}

RegistrationFlow flowFor(FakeBackend b) => RegistrationFlow(
  b,
  authTimeout: const Duration(milliseconds: 60),
  stepTimeout: const Duration(milliseconds: 60),
  claimTimeout: const Duration(milliseconds: 60),
);

Future<void> signUp(RegistrationFlow f, {String password = 'Passw0rd!x'}) =>
    f.register(
      username: 'Juan',
      password: password,
      phoneNumber: '+639171234567',
    );

Matcher failsWith(RegistrationError e) =>
    throwsA(isA<RegistrationException>().having((x) => x.error, 'error', e));

void main() {
  test('success writes the profile and the username together, once', () async {
    final b = FakeBackend();
    await signUp(flowFor(b));
    expect(b.auth.length, 1);
    expect(b.usernames['Juan'], b.users.keys.single);
    expect(b.users.values.single['registrationComplete'], true);
    expect(b.users.values.single['phoneVerified'], false);
  });

  test('the email is stored trimmed and lower-case, and reserved', () async {
    final b = FakeBackend();
    await flowFor(b).register(
      username: 'Juan',
      password: 'Passw0rd!x',
      phoneNumber: '+639171234567',
      recoveryEmail: '  Juan@Email.COM ',
    );
    expect(b.users.values.single['recoveryEmail'], 'juan@email.com');
    expect(b.emails['juan@email.com'], b.users.keys.single);
  });

  test('an email already used by another account is refused, ignoring case '
      'and spaces, and the new sign-in account is removed', () async {
    final b = FakeBackend()..emails['user@email.com'] = 'someoneElse';
    await expectLater(
      flowFor(b).register(
        username: 'Juan',
        password: 'Passw0rd!x',
        phoneNumber: '+639171234567',
        recoveryEmail: 'User@Email.com ',
      ),
      failsWith(RegistrationError.emailTaken),
    );
    expect(b.hasNothing, isTrue);
    expect(b.emails['user@email.com'], 'someoneElse');
  });

  test('a phone number already used by another account is refused and '
      'the new sign-in account is removed', () async {
    final b = FakeBackend()..phones['+639171234567'] = 'someoneElse';
    await expectLater(
      signUp(flowFor(b)),
      failsWith(RegistrationError.phoneTaken),
    );
    expect(b.hasNothing, isTrue);
    expect(b.phones['+639171234567'], 'someoneElse');
    expect(b.signedInUid, isNull);
  });

  group('a number held by a ghost account is freed', () {
    test(
      'the phone number held by a ghost: the sign-up goes through',
      () async {
        final b = FakeBackend()
          ..phones['+639171234567'] = 'ghostUid'
          ..ghostPhones.add('+639171234567');
        await signUp(flowFor(b));
        expect(b.releaseCalls, ['phone:+639171234567']);
        expect(b.users.length, 1);
        expect(b.phones['+639171234567'], b.users.keys.single);
      },
    );

    test('a number held by a REAL account is still refused', () async {
      final b = FakeBackend()..phones['+639171234567'] = 'realUid';
      await expectLater(
        signUp(flowFor(b)),
        failsWith(RegistrationError.phoneTaken),
      );
      expect(b.releaseCalls, ['phone:+639171234567']); // asked, said no
      expect(b.phones['+639171234567'], 'realUid');
      expect(b.hasNothing, isTrue);
    });

    test(
      'if the server cannot be asked, it stays "taken", as before',
      () async {
        final b = FakeBackend()
          ..phones['+639171234567'] = 'ghostUid'
          ..ghostPhones.add('+639171234567')
          ..releaseFails = true;
        await expectLater(
          signUp(flowFor(b)),
          failsWith(RegistrationError.phoneTaken),
        );
        expect(b.hasNothing, isTrue);
      },
    );

    test('a ghost email is freed the same way', () async {
      final b = FakeBackend()
        ..emails['juan@example.com'] = 'ghostUid'
        ..ghostEmails.add('juan@example.com');
      await flowFor(b).register(
        username: 'Juan',
        password: 'Passw0rd!x',
        phoneNumber: '+639171234567',
        recoveryEmail: ' Juan@Example.com ',
      );
      expect(b.releaseCalls, ['email:juan@example.com']);
      expect(b.users.length, 1);
    });

    test('a ghost number and a ghost email in one sign-up', () async {
      final b = FakeBackend()
        ..phones['+639171234567'] = 'g1'
        ..emails['juan@example.com'] = 'g2'
        ..ghostPhones.add('+639171234567')
        ..ghostEmails.add('juan@example.com');
      await flowFor(b).register(
        username: 'Juan',
        password: 'Passw0rd!x',
        phoneNumber: '+639171234567',
        recoveryEmail: 'juan@example.com',
      );
      expect(b.users.length, 1);
    });
  });

  test(
    'your own earlier attempt keeps its phone reservation on a retry',
    () async {
      final b = FakeBackend()..goOfflineAfterCreate = true;
      final flow = flowFor(b);
      await expectLater(signUp(flow), failsWith(RegistrationError.network));
      b.offline = false;
      b.goOfflineAfterCreate = false;
      await signUp(flow);
      expect(b.phones['+639171234567'], b.users.keys.single);
    },
  );

  test('no email at all is still fine (it is optional)', () async {
    final b = FakeBackend();
    await signUp(flowFor(b));
    expect(b.emails, isEmpty);
    expect(b.users.values.single.containsKey('recoveryEmail'), isFalse);
  });

  group('phone OR email (either one is enough)', () {
    test('email only: no phone is stored or reserved', () async {
      final b = FakeBackend();
      await flowFor(b).register(
        username: 'Juan',
        password: 'Passw0rd!x',
        recoveryEmail: ' Juan@Email.com ',
        verificationMethod: 'email',
      );
      final user = b.users.values.single;
      expect(user['recoveryEmail'], 'juan@email.com');
      expect(user['verificationMethod'], 'email');
      expect(user.containsKey('phoneNumber'), isFalse);
      expect(b.emails['juan@email.com'], b.users.keys.single);
      expect(b.phones, isEmpty);
    });

    test('phone only: no email is stored or reserved', () async {
      final b = FakeBackend();
      await signUp(flowFor(b));
      final user = b.users.values.single;
      expect(user['phoneNumber'], '+639171234567');
      expect(user['verificationMethod'], 'phone');
      expect(user.containsKey('recoveryEmail'), isFalse);
      expect(b.emails, isEmpty);
    });

    test('an empty phone counts as not given', () async {
      final b = FakeBackend();
      await flowFor(b).register(
        username: 'Juan',
        password: 'Passw0rd!x',
        phoneNumber: '   ',
        recoveryEmail: 'juan@email.com',
        verificationMethod: 'email',
      );
      expect(b.users.values.single.containsKey('phoneNumber'), isFalse);
    });

    test(
      'neither one: refused before any sign-in account is created',
      () async {
        final b = FakeBackend();
        await expectLater(
          flowFor(b).register(
            username: 'Juan',
            password: 'Passw0rd!x',
            phoneNumber: ' ',
          ),
          failsWith(RegistrationError.unknown),
        );
        expect(b.createCalls, 0);
        expect(b.hasNothing, isTrue);
      },
    );

    test('the chosen method needs its own identifier', () async {
      final b = FakeBackend();
      // Email method with only a phone number...
      await expectLater(
        flowFor(b).register(
          username: 'Juan',
          password: 'Passw0rd!x',
          phoneNumber: '+639171234567',
          verificationMethod: 'email',
        ),
        failsWith(RegistrationError.unknown),
      );
      // ...and phone method with only an email.
      await expectLater(
        flowFor(b).register(
          username: 'Juan',
          password: 'Passw0rd!x',
          recoveryEmail: 'juan@email.com',
          verificationMethod: 'phone',
        ),
        failsWith(RegistrationError.unknown),
      );
      expect(b.createCalls, 0);
    });

    test(
      'a duplicate email is still refused when it is the only one',
      () async {
        final b = FakeBackend()..emails['user@email.com'] = 'someoneElse';
        await expectLater(
          flowFor(b).register(
            username: 'Juan',
            password: 'Passw0rd!x',
            recoveryEmail: 'User@Email.com',
            verificationMethod: 'email',
          ),
          failsWith(RegistrationError.emailTaken),
        );
        expect(b.hasNothing, isTrue);
      },
    );
  });

  test('a username owned by someone else is refused before anything is '
      'created', () async {
    final b = FakeBackend()..usernames['Juan'] = 'someoneElse';
    await expectLater(
      signUp(flowFor(b)),
      failsWith(RegistrationError.usernameTaken),
    );
    expect(b.createCalls, 0);
    expect(b.auth, isEmpty);
    expect(b.users, isEmpty);
  });

  test(
    'no internet at the start: a network message, nothing created',
    () async {
      final b = FakeBackend()..offline = true;
      await expectLater(
        signUp(flowFor(b)),
        failsWith(RegistrationError.network),
      );
      expect(b.hasNothing, true);
    },
  );

  test('timeout after the sign-in account was created: retry continues, '
      'never "already registered"', () async {
    final b = FakeBackend()..authHangsAfterCreating = true;
    // The first attempt gives up waiting but finds the account it made and
    // finishes the sign-up.
    await signUp(flowFor(b));
    expect(b.usernames['Juan'], isNotNull);
    expect(b.users.values.single['registrationComplete'], true);

    // Same again from a clean slate, with the claim also failing offline.
    final c = FakeBackend()..authHangsAfterCreating = true;
    await signUp(flowFor(c));
    expect(c.auth.length, 1);
  });

  test('connection drops after the account exists: nothing visible is '
      'half-made and the retry succeeds', () async {
    final b = FakeBackend()..goOfflineAfterCreate = true;
    final flow = flowFor(b);
    await expectLater(signUp(flow), failsWith(RegistrationError.network));
    // No profile, no username reserved: invisible to the Admin portal.
    expect(b.users, isEmpty);
    expect(b.usernames, isEmpty);
    expect(b.signedInUid, isNull);
    expect(b.auth.length, 1); // kept, so the retry can continue from it

    // Back online: the same person tries again with the same password.
    b.offline = false;
    b.goOfflineAfterCreate = false;
    await signUp(flow);
    expect(b.usernames['Juan'], isNotNull);
    expect(b.users.values.single['registrationComplete'], true);
    expect(b.auth.length, 1);
  });

  test('claim timed out but had committed: treated as success', () async {
    final b = FakeBackend()..claimHangsAfterCommit = true;
    await signUp(flowFor(b));
    expect(b.users.values.single['registrationComplete'], true);
    expect(b.auth.length, 1);
  });

  test(
    'claim definitely failed: the new sign-in account is rolled back',
    () async {
      final b = FakeBackend()
        ..claimThrows = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      await expectLater(
        signUp(flowFor(b)),
        failsWith(RegistrationError.saveFailed),
      );
      expect(b.hasNothing, true);
      expect(b.signedInUid, isNull);
    },
  );

  test(
    'claim timed out and the server shows nothing saved: rolled back',
    () async {
      final b = FakeBackend()..claimFailsBeforeCommit = true;
      await expectLater(
        signUp(flowFor(b)),
        failsWith(RegistrationError.timeout),
      );
      expect(b.hasNothing, true);
    },
  );

  test(
    'someone else claimed the username in the meantime: rolled back',
    () async {
      final b = FakeBackend()..claimLosesRace = true;
      await expectLater(
        signUp(flowFor(b)),
        failsWith(RegistrationError.usernameTaken),
      );
      expect(b.hasNothing, true);
    },
  );

  test(
    'own earlier attempt that did finish: carries on, writes nothing new',
    () async {
      final b = FakeBackend();
      await signUp(flowFor(b));
      final users = Map.of(b.users);
      b.signedInUid = null;
      await signUp(flowFor(b)); // the user taps Sign Up again
      expect(b.users, users);
      expect(b.createCalls, 1);
    },
  );

  test('a verified, in-use account is never registered over', () async {
    final b = FakeBackend();
    await signUp(flowFor(b));
    b.users.values.single['phoneVerified'] = true;
    await expectLater(
      signUp(flowFor(b)),
      failsWith(RegistrationError.alreadyRegistered),
    );
    expect(b.users.values.single['phoneVerified'], true);
  });

  test('an unfinished sign-up with a different password gets a specific '
      'message, not a generic one', () async {
    final b = FakeBackend();
    b.auth['juan@fineaid.app'] = (password: 'OldPassw0rd!', uid: 'orphan');
    await expectLater(
      signUp(flowFor(b), password: 'NewPassw0rd!'),
      failsWith(RegistrationError.alreadyRegistered),
    );
    expect(b.users, isEmpty);
  });

  test('an orphan sign-in account is adopted when the same password is '
      'used', () async {
    final b = FakeBackend();
    b.auth['juan@fineaid.app'] = (password: 'Passw0rd!x', uid: 'orphan');
    await signUp(flowFor(b));
    expect(b.usernames['Juan'], 'orphan');
    expect(b.users['orphan']!['registrationComplete'], true);
    expect(b.auth.length, 1);
  });

  group('personal details', () {
    test('first name, last name, date of birth, gender are saved', () async {
      final b = FakeBackend();
      await flowFor(b).register(
        username: 'Juan',
        password: 'Passw0rd!x',
        phoneNumber: '+639171234567',
        firstName: '  Juan ',
        lastName: 'Dela Cruz',
        dateOfBirth: DateTime(2000, 1, 15, 13, 30),
        gender: 'male',
      );
      final user = b.users.values.single;
      expect(user['firstName'], 'Juan');
      expect(user['lastName'], 'Dela Cruz');
      expect(user['gender'], 'male');
      // the day only, as a Firestore timestamp
      expect(
        (user['dateOfBirth'] as Timestamp).toDate(),
        DateTime(2000, 1, 15),
      );
      expect(user.containsKey('underageAcknowledged'), isFalse);
    });

    test('an underage acknowledgment is saved with its timestamp', () async {
      final b = FakeBackend();
      await flowFor(b).register(
        username: 'Juan',
        password: 'Passw0rd!x',
        phoneNumber: '+639171234567',
        underageAcknowledged: true,
      );
      final user = b.users.values.single;
      expect(user['underageAcknowledged'], true);
      expect(user.containsKey('underageAcknowledgedAt'), isTrue);
    });

    test(
      'without them nothing new is written (older callers unchanged)',
      () async {
        final b = FakeBackend();
        await signUp(flowFor(b));
        final user = b.users.values.single;
        for (final key in [
          'firstName',
          'lastName',
          'dateOfBirth',
          'gender',
          'underageAcknowledged',
        ]) {
          expect(user.containsKey(key), isFalse, reason: key);
        }
      },
    );
  });
}
