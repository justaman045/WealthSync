<div align="center">
  <img src="assets/app_logo.png" alt="WealthSync Logo" width="96" height="96"/>
  <h1>WealthSync</h1>
  <p><b>Your Pocket CFO</b> — track expenses, build wealth, automate finances</p>

  [![Release](https://img.shields.io/github/v/release/justaman045/WealthSync?color=6C5CE7&style=flat-square)](https://github.com/justaman045/WealthSync/releases)
  [![Tests](https://github.com/justaman045/WealthSync/actions/workflows/flutter_build.yml/badge.svg)](https://github.com/justaman045/WealthSync/actions/workflows/flutter_build.yml)
  [![License](https://img.shields.io/github/license/justaman045/WealthSync?style=flat-square)](LICENSE)
  [![Platform](https://img.shields.io/badge/Android-73C36A?style=flat-square&logo=android)](https://github.com/justaman045/WealthSync/releases)
  [![Flutter](https://img.shields.io/badge/Flutter-3.35-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
  [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square)](CONTRIBUTING.md)
</div>

<p align="center">
  <b>Privacy-first</b> • <b>Offline-ready</b> • <b>AI-powered</b> • <b>24 asset types</b>
</p>

---

## Why WealthSync?

Most finance apps are cluttered, invasive, or ugly. **WealthSync** is a modern, privacy-first financial companion that combines beautiful design with powerful automation and complete wealth tracking.

| | |
|---|---|
| **🔒 Privacy First** | Your data stays yours. Offline-first architecture with biometric lock. No data sold. |
| **🤖 AI Automation** | Pro tier reads bank SMS via on-device ML and auto-categorizes transactions. |
| **📊 Wealth Management** | Track 24 asset types — stocks, real estate, crypto, gold, PF, NPS, and more. |
| **🎨 Beautiful Design** | Glassmorphic UI with smooth animations. Full dark mode support. |
| **📱 UPI Payments** | Native UPI integration — send money directly from the app. |

---

## Features

### Free Forever

- **Dashboard** — Monthly balance, spending trends, quick insights
- **Expense Tracking** — Add income/expenses in seconds
- **Visual Analytics** — Interactive charts (fl_chart)
- **Wealth Portfolio** — 24 asset types, custom entries, targets
- **Custom Categories** — Organize spending your way
- **Offline Support** — Full functionality without internet
- **Biometric Lock** — Fingerprint / face unlock
- **Budgeting** — Monthly budgets with alerts
- **Savings Goals** — Track and visualize progress
- **Recurring Payments** — Auto-track subscriptions and EMIs
- **Lent Money Tracking** — Track loans between friends
- **Savings Challenges** — Gamified saving streaks
- **CSV/PDF Export** — Export your data

### Pro 💎

| Feature | Free | Pro |
|---|---|---|
| Transactions/mo | 150 | Unlimited |
| Categories | 10 | Unlimited |
| SMS Auto-Tracking | ❌ | ✅ AI-powered |
| Smart Budget Alerts | ❌ | ✅ |
| Advanced Analytics | Basic | Lifetime history |
| Receipt OCR | ❌ | ✅ |
| Priority Support | Standard | Priority |
| **Price** | **Free** | **₹249/mo** |

---

## Screenshots

<!-- TODO: Add light/dark mode screenshots -->
<!-- 
| Dashboard | Wealth | Analytics | SMS Import |
|:---:|:---:|:---:|:---:|
| ![Dashboard](screenshots/dashboard.png) | ![Wealth](screenshots/wealth.png) | ![Analytics](screenshots/analytics.png) | ![SMS](screenshots/sms.png) |
-->

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter (Dart SDK ^3.9.2) |
| **State Management** | GetX |
| **Backend** | Firebase Auth, Firestore, Crashlytics, Messaging, Storage, Performance |
| **Architecture** | MVC-Service-Repository |
| **SMS / OCR** | google_mlkit_text_recognition |
| **Charts** | fl_chart |
| **Payments** | UPI via Kotlin MethodChannel |
| **Auth** | Email/Password, Google Sign-In, Apple Sign-In |
| **Responsive** | flutter_screenutil (390×844 reference) |

---

## Quick Start

```bash
# Clone
git clone https://github.com/justaman045/WealthSync.git
cd WealthSync

# Install dependencies
flutter pub get

# Run tests
flutter test

# Analyze
flutter analyze

# Run app
flutter run

# Build release APK
flutter build apk --release
```

---

## Download

**Latest APK:** https://github.com/justaman045/WealthSync/releases/download/v2.0.124/app-release.apk

*Installation:* Download the `.apk` on your Android device, open it, and allow installation from unknown sources.

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) to get started.

- Found a bug? [Open an issue](https://github.com/justaman045/WealthSync/issues/new?labels=bug)
- Have an idea? [Open a feature request](https://github.com/justaman045/WealthSync/issues/new?labels=enhancement)

---

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">
  Made with ❤️
</div>
