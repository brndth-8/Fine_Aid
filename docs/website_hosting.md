# Fine Aid Website + Admin — Hosting & Deployment

One Flutter web build (`lib/main_web.dart`) serves both the public site and the
admin module from the same domain:

| URL | Serves |
|---|---|
| `https://www.fineaid.com/` | Public landing page (About, Experts, Contact Us, Download) |
| `https://www.fineaid.com/<ADMIN_PATH>` | Admin module (login → dashboard) |
| anything else | Static `404.html` with a real **HTTP 404** status |

`fineaid.com` is a **placeholder** until the GoDaddy domain is purchased. The
app itself contains no domain references — only `web/robots.txt` and
`web/sitemap.xml` do (search engines require absolute URLs there).

---

## 1. The secret admin path

The current path is set in **two files that must match**:

- `config/web.json` → `"ADMIN_PATH"` (compiled into the app)
- `firebase.json` → `hosting.rewrites` and `hosting.headers` (tells the server to serve the app there)

To change it, generate a new random slug, e.g.

```bash
python -c "import secrets,string;print('fa-portal-'+''.join(secrets.choice(string.ascii_lowercase+string.digits) for _ in range(8)))"
```

then replace the old value in both files and rebuild/redeploy.

How the path is hidden:

- It is not linked from the public site, footer, `robots.txt` or `sitemap.xml`.
- Guessed paths (`/admin`, `/login`, `/fa-portal`, …) get the same generic 404 as any other bad URL.
- Responses on the admin path carry `X-Robots-Tag: noindex, nofollow, noarchive`, so search engines won't index it even if they find it.
- Responses on the admin path also carry `Referrer-Policy: no-referrer`, so the URL isn't leaked to other sites the admin clicks through to.
- The admin screens and the Firebase SDK are a **deferred bundle** (`main.dart.js_1.part.js`). Public visitors never download them.

> **About robots.txt:** the brief asks both to keep the path out of
> `robots.txt` *and* to `Disallow` it there. Those conflict: `robots.txt` is
> public, so a `Disallow` line would advertise the path to anyone who reads it. We
> use the `X-Robots-Tag` header instead, which achieves the same "don't index"
> result without revealing the path.

### ⚠️ Note for the client: this is security by obscurity

A secret URL only stops *casual* discovery. It can still leak through browser
history, shared links, screenshots, server logs, or someone reading the compiled
JavaScript (the slug is in `main.dart.js`, since the app has to recognise it).
**The login screen is the real gate**, and it's already in place:

- Firebase Authentication. After signing in, the account must also have a document in the `admins` collection, or it is signed out again (`lib/features/admin/admin_gate.dart`).
- Failed-login lockout via `loginAttempts` (existing admin login screen).
- HTTPS is enforced automatically by Firebase Hosting, and `Strict-Transport-Security` is set in `firebase.json`.

Optional hardening the client can choose later:

- **2FA:** Firebase Auth supports SMS/TOTP multi-factor. Enabling it requires upgrading to Identity Platform.
- **IP allowlisting:** not supported by Firebase Hosting itself. It needs Cloud Armor in front of the site, or enforcement in Firestore rules/Cloud Functions.
- **Firebase App Check:** blocks scripted abuse of the backend APIs.
- **Role-based access:** add a `role` field (e.g. `super_admin`, `content_editor`, `viewer`) to each `admins/{uid}` document. Then check it in the dashboard and in `firestore.rules`.

---

## 2. Build & test locally

```bash
flutter build web -t lib/main_web.dart --dart-define-from-file=config/web.json
```

```bash
python tool/serve_web.py
```

`tool/serve_web.py` serves `build/web` at http://localhost:5960 and mimics the
Firebase rules: `/` and the admin path serve the app, everything else returns a 404.

Tests:

```bash
flutter test test/website --dart-define-from-file=config/web.json
```

For live development, use `flutter run -t lib/main_web.dart -d chrome --dart-define-from-file=config/web.json`.
`lib/main_admin.dart` still runs the admin module on its own.

---

## 3. Deploy (Firebase Hosting)

The project already uses Firebase (`fine-aid-9e0a9`), so the site is deployed to
Firebase Hosting. SSL certificates are free and renew automatically.

```bash
npm install -g firebase-tools
```

```bash
firebase login
```

```bash
flutter build web -t lib/main_web.dart --dart-define-from-file=config/web.json
```

```bash
firebase deploy --only hosting
```

The site is then live at `https://fine-aid-9e0a9.web.app` before any custom domain is connected.

---

## 4. Connect the GoDaddy domain (once purchased)

1. **Firebase Console → Hosting → Add custom domain.** Add `www.fineaid.com` (the final domain). Also add `fineaid.com`, set to *redirect* to `www`.
2. Firebase shows the DNS records to create. In **GoDaddy → My Products → Domain → DNS → Manage DNS**:
   - Add the **TXT** record (domain ownership verification).
   - Add the **A** records for `fineaid.com` (`@`), exactly as Firebase lists them. Delete GoDaddy's default "Parked" A record first.
   - Add the **CNAME** or A record for `www`, as Firebase lists it.
3. Wait for DNS to propagate. This usually takes minutes but can take up to 24h. Firebase then issues the SSL certificate automatically, and HTTP is redirected to HTTPS.
4. **Firebase Console → Authentication → Settings → Authorized domains:** add both `fineaid.com` and `www.fineaid.com`. Without this, admin login fails on the new domain.
5. Replace the placeholder domain in `web/robots.txt` and `web/sitemap.xml`, then rebuild and redeploy.
6. *(Optional)* Submit the sitemap in Google Search Console.

Keep the domain registered at GoDaddy. Only its DNS records point to Firebase. No GoDaddy hosting plan is needed.

---

## 5. Content still to supply

- Hero, download, About lifestyle, and world-map photos, plus the QR code. See `assets/web/README.md`.
- *(Optional)* The original footer photo. The current one is cropped from the mockup PDF.
- *(Optional)* An SVG logo, so the heartbeat pulses only the red cross (see `AnimatedLogo` in `lib/features/website/landing_page.dart`).

## 6. Known trade-off: Flutter web and SEO

Flutter draws the page on a canvas, so search engines see less text than they
would on a plain HTML site. To help, `web/index.html` includes:

- the page title and meta description
- Open Graph tags for link previews
- a `<noscript>` summary

This is fine for a brand/download page. If organic search ranking becomes
important, the public landing page could be rebuilt later as static HTML while
the admin stays in Flutter.
