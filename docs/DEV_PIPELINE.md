# Fine Aid — Developer Pipeline & "Don't Forget" Sheet

Everything a developer must remember to build, run, and ship Fine Aid.
**This file lists where secrets live — never paste secret values into it.**

## 1. Critical data (NOT in git — back these up!)

If your machine dies, these cannot be recovered from the repo.

| Item | Location | Why it matters | Back up in |
|---|---|---|---|
| Android signing keystore | `android/app/release.keystore` | Lose it = can never update the published app | Password manager / encrypted drive |
| Keystore alias + passwords | `android/app/build.gradle.kts` (`signingConfigs`) | Needed to sign releases | Password manager |
| Gemini + Semaphore keys | `lib/core/constants/api_keys.dart` (gitignored) | App won't compile without this file | Password manager |
| Android Firebase config | `android/app/google-services.json` (gitignored) | Android build fails without it | Re-download from Firebase console |
| Firebase Admin key | `seed_firestore/serviceAccountKey*.json` (gitignored) | Full DB admin access — used by the seeder | Password manager; delete the `(2)` duplicate |
| Cloud Functions secrets | Firebase Secret Manager: `SEMAPHORE_API_KEY`, `SMTP_USER`, `SMTP_PASS` | SMS/email OTP stops working | Password manager |
| Secret admin URL slug | `config/web.json` **and** `firebase.json` (must match) | Admin portal path; see `docs/website_hosting.md` | — |

Tracked in git (safe, public identifiers): `lib/firebase_options.dart`, `.firebaserc`, `firebase.json`.

## 2. Key identifiers

- Firebase project: `fine-aid-9e0a9`
- Flutter SDK constraint: `^3.12.0` (see `pubspec.yaml`)
- Cloud Functions runtime: Node 20 (`functions/`)
- Android applicationId: `com.example.fine_aid` (placeholder — change before Play Store release)
- App version: `pubspec.yaml` → `version: x.y.z+build` (bump build number every release)

## 3. New machine setup

```bash
git clone <repo> && cd fine_aid
flutter pub get
cd functions && npm ci && cd ..
```

Then restore the gitignored files from section 1:
1. Create `lib/core/constants/api_keys.dart` with `ApiKeys.gemini` and `ApiKeys.semaphore` constants.
2. Put `google-services.json` in `android/app/`.
3. Put `release.keystore` in `android/app/`.
4. (Only for seeding) put `serviceAccountKey.json` in `seed_firestore/`.

## 4. The pipeline

```
code  ->  analyze/test  ->  build  ->  deploy  ->  verify
```

| Stage | Command |
|---|---|
| Run mobile app | `flutter run` |
| Run web (site + admin) | `flutter run -d chrome -t lib/main_web.dart --dart-define-from-file=config/web.json` |
| Analyze | `flutter analyze` |
| Test | `flutter test` |
| Build Android (signed) | `flutter build apk --release` (or `appbundle`) |
| Build web | `flutter build web -t lib/main_web.dart --release --dart-define-from-file=config/web.json` |
| Deploy hosting | `firebase deploy --only hosting` |
| Deploy rules/indexes | `firebase deploy --only firestore` |
| Deploy functions | `firebase deploy --only functions` |
| Set a function secret | `firebase functions:secrets:set SEMAPHORE_API_KEY` |
| Seed first-aid content | `cd seed_firestore && npm install && node seed.js` |

**Order for a full release:** analyze -> test -> bump version -> build web -> `firebase deploy` (firestore rules first if changed) -> build signed APK -> smoke test.

## 5. Pre-release checklist

- [ ] `flutter analyze` and `flutter test` pass
- [ ] Version/build number bumped in `pubspec.yaml`
- [ ] Web built **with** `--dart-define-from-file=config/web.json` (otherwise admin path is empty)
- [ ] `ADMIN_PATH` in `config/web.json` matches `firebase.json` rewrites/headers
- [ ] Firestore rules/indexes deployed if changed
- [ ] Functions deployed and secrets set if changed
- [ ] APK signed with `release.keystore` (never a debug key)
- [ ] OTP SMS + email, Gemini chat, and camera triage smoke-tested

## 6. Known gotchas / security to-dos

- Keystore passwords are hardcoded in tracked `build.gradle.kts`. Move them to a gitignored `key.properties` and **rotate** them.
- `api_keys.dart` compiles API keys into the app binary; anyone can extract them. Restrict the keys in Google Cloud / Semaphore, or proxy calls through Cloud Functions.
- `seed_firestore/serviceAccountKey*.json` gives full admin access. Rotate if ever shared; keep out of screenshots and chat logs.
- Domain `fineaid.com` is a placeholder (`web/robots.txt`, `web/sitemap.xml`).
- `build/`, `.dart_tool/`, and `node_modules/` are safe to delete and regenerate.

## 7. Mobile app — main functionalities

Entry: `lib/main.dart` (routes below). Onboarding gate in `main.dart` decides the next screen from flags on `users/{uid}`.

**Sign-up / login pipeline** (each step is a flag on the user doc; a user resumes at the first unmet one):
`Login/Registration` -> `OTP` (`phoneVerified`, SMS via Semaphore) -> `Terms` (`termsAccepted`) -> `Permission` -> `Health checklist` (diabetes / blood disorders / severe allergies) -> `Dashboard`.
- Username login: `usernames/{username}` maps to a generated email; `loginAttempts/{username}` powers lockout. See `auth_service.dart`.
- Password reset by SMS or email OTP through Cloud Functions (`sendPasswordResetOtp`, `sendPasswordResetOtpEmail`, `verifyPasswordResetOtp`, plus account-verification OTP functions). Shared password rules: `core/password_requirements.dart`.
- **Guest mode**: dashboard works without an account; profile and journal are gated (`guest_profile_gate_screen.dart`).

| Feature | Where | How it works / what to remember |
|---|---|---|
| **AI Camera** (wound/skin scan) | `features/camera/`, `gemini_service.dart` | `detectWounds` runs a "Free Pass Filter" (confidence threshold; rejects pen marks, makeup, screenshots) before `analyzeWoundV2`. Multiple injuries in one photo go through `analyzeMultipleWoundsV2` -> `multi_injury_result_screen`. Output: classification, SEVERITY (normal/urgent), TriageLevel (selfCare/firstAid/urgentCare/emergency). Uses Gemini model `gemini-3.5-flash`. |
| **AI chatbot / follow-up Q&A** | `features/chatbot/`, `sendChatMessage` | Answers are grounded with `firstAidContent` chunks (`first_aid_content_service.buildReferenceContext`). Failures show friendly text via `core/follow_up_fallback.dart`, never raw errors. Voice questions: on-device speech (`voice_input_service.dart`), works offline. |
| **OTC suggestions** | `otc_filter_service.dart`, `assets/config/otc_filter_config.json` | Gemini's "OTC:" lines are validated against a denylist + allowlist; failures are dropped silently. Tune the JSON, not Dart. |
| **First Aid Health Kit** | `features/dashboard/first_aid_kit_screen.dart`, `i18n/` | Guides with health-profile cautions (`health_profile_cautions.dart`); English/Tagalog toggle, persisted. |
| **Textbook / manuals** | `textbook_viewer_screen.dart`, `assets/pdfs/` | Bundled PDFs (First Aid and CPR Manual, pocket/reference guides) -- check the right PDF is mapped to each card. |
| **Health Journal** | `features/journal/` | Entries in `users/{uid}/journalEntries` (title, description, severity, classification, images, `remindMe`). Healing check-in reminders via local notifications (`notification_service.scheduleHealingCheckIn`, durations in `data/healing_durations.dart`). Export to PDF: `export_service.dart`. Photos in Storage `users/{uid}/...`. |
| **Nearby healthcare** | `nearby_healthcare_sheet.dart`, `data/healthcare_facilities.dart` | Static bundled directory. No maps, location or network -- update the Dart list to add facilities. |
| **Notifications** | `notification_service.dart`, `notifications_screen.dart` | FCM push + local. Listens for admin announcements in `systemNotifications`; per-user log in `users/{uid}/notifications`. |
| **Profile & Settings** | `features/settings/` | Edit profile (photo local + Storage), Personalization (text size via `text_scale_controller.dart`), Feedback (-> `feedback`), Help/FAQ, About, in-app help tour. |
| **Offline** | `connectivity_service.dart`, `connectivity_badge.dart` | Badge shows offline; guides, facilities, voice and bundled PDFs work without internet. Gemini, OTP and sync need network. |

## 8. Admin module -- functionalities

Entry: `lib/main_web.dart` (production, at the secret `ADMIN_PATH`) or `lib/main_admin.dart` (local dev). Flow: `admin_gate.dart` -> not signed in: `AdminLandingScreen`/`AdminLoginScreen`; signed in **and** doc exists at `admins/{uid}`: `AdminDashboardScreen`; otherwise auto sign-out.

**To add an admin:** create user in Firebase Auth, then manually create `admins/{uid}` in the Firestore console (rules block app writes to `admins`).

| Section | File (`features/admin/screens/sections/`) | What it does | Data |
|---|---|---|---|
| Dashboard | `admin_main_dashboard.dart` | Totals, recent activity feed, system status | `users`, `journalEntries` (group), `auditLogs` |
| User Management | `admin_user_management.dart` | List, search, add (via a secondary Firebase app so the admin stays signed in), edit, activate/deactivate (`deactivated` flag) | `users`, `usernames` |
| Content Management | `admin_content_management.dart` | Create/edit first-aid articles, "Offline available" flag; feeds the chatbot's reference context | `firstAidContent` |
| Notifications | `admin_notifications.dart` | Send now or schedule announcements (audience + priority). Delivered by Cloud Functions `sendSystemNotificationPush` (on create) and `sendScheduledSystemNotifications` (schedule) | `systemNotifications` |
| Journal Log Review | `admin_journal_log_review.dart` | Read-only review of all users' entries | `journalEntries` (collection group) |
| Feedback | `admin_feedback.dart` | View and update status of user feedback | `feedback` |
| Reports & Analytics | `admin_reports_analytics.dart` | CSV exports: user activity, journal log, auto-referrals, app usage summary | `users`, `journalEntries` |
| Audit Logs | `admin_audit_logs.dart` | Every admin action (`logAdminAction`) with CSV export | `auditLogs` |
| System Security | `admin_system_security.dart` | Security toggles UI (session timeout, lockout, retention) | **UI only** -- see below |

## 9. Firestore data map

`users/{uid}` (+ `journalEntries`, `notifications`), `usernames`, `admins`, `loginAttempts`, `otpVerifications`, `feedback`, `firstAidContent`, `systemNotifications`, `auditLogs`. Rules: `firestore.rules`. Storage: `users/{uid}/profile/photo.jpg` and journal images.

## 10. Firestore rules -- status and remaining weak spots

`firestore.rules` now enforces admin access server-side via `isAdmin()` (a doc in `admins/{uid}`):
- `firstAidContent`, `systemNotifications`, `auditLogs`: admin-only write (`auditLogs` and `feedback` are admin-only read too).
- `feedback`: users may only create as themselves (`userId == auth.uid`).
- `users`: readable/updatable by owner or admin only; owners cannot change their own `deactivated` flag.
- `journalEntries` collection group: admin read only; owners use their own subcollection.
- `usernames`: public read (needed before login), but only the owning uid (or an admin) can write.
- **Rules must be deployed** to take effect: `firebase deploy --only firestore:rules`. Test login, registration, feedback, journal, and every admin section afterwards.

Still open:
- `loginAttempts` must stay world-readable/writable (lockout runs before login); rules only restrict its shape. Real lockout needs a Cloud Function.
- Admin **System Security** toggles and summary numbers are static UI, not enforced.
- Client-side Gemini/Semaphore keys ship in the app (see section 6).

## 11. Other docs


- `docs/website_hosting.md` — web hosting and secret admin path
- `seed_firestore/README.md` — Firestore content seeding
