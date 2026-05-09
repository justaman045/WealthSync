# Contributing

Thank you for considering contributing to WealthSync!

## Code of Conduct

This project follows a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## How to Contribute

### 1. Find or Create an Issue

- Browse [open issues](https://github.com/justaman045/Finance-Control/issues)
- Or create a [new issue](https://github.com/justaman045/Finance-Control/issues/new) describing the bug or feature

### 2. Fork & Branch

```bash
git clone https://github.com/your-username/Finance-Control.git
cd Finance-Control
git checkout -b feat/my-feature
```

### 3. Make Changes

- Follow existing code style and patterns
- Add tests for new functionality
- Ensure `flutter analyze` passes with zero errors
- Ensure `flutter test` passes all tests

### 4. Commit & Push

```bash
git add .
git commit -m "feat: add my feature"
git push origin feat/my-feature
```

### 5. Open a Pull Request

- PR description should explain *what* and *why*
- Link to the related issue
- Include screenshots for UI changes
- Ensure CI (tests + analyze) passes

## Development Setup

```bash
# Install dependencies
flutter pub get

# Run tests
flutter test

# Run analyzer
flutter analyze --no-fatal-infos
```

## Project Structure

| Directory | Purpose |
|---|---|
| `lib/Controllers/` | GetX state controllers |
| `lib/Models/` | Data classes with `fromMap`/`toMap` |
| `lib/Repositories/` | Firestore data access |
| `lib/Screens/` | UI screens |
| `lib/Components/` | Reusable widgets |
| `lib/Services/` | Business logic |
| `lib/Config/` | Asset configurations |
| `lib/Utils/` | Helpers |

## Need Help?

Open a [discussion](https://github.com/justaman045/Finance-Control/discussions) or ask in the issue.
