# AGENTS.md: Flutter project rules

<!-- Based on github.com/ChandraChaan/flutter-agent-skills. -->

## This project

- **What it is:** Data Pack Meter, an Android app: live speed in the status bar, daily/monthly data pack tracking and per-app use. Everything on the device.
- **State management:** Riverpod 3 (`Notifier`, `AsyncNotifier`). Automatic retries are off (`noRetry`); screens have their own retry.
- **Navigation:** three tabs in `HomeShell` (`lib/app.dart`); no router package.
- **Folders:** feature-first, `lib/features/<feature>/{data,domain,presentation}`, shared code in `lib/core/`.
- **Platform code:** Kotlin in `android/app/src/main/kotlin/`, reached only through the channel in `lib/core/platform/native_channel.dart` and the `Channel*Repository` classes. Pure Kotlin logic (speed sampling, formatting, pack periods, alerts) has JVM unit tests: `cd android && ./gradlew :app:testDebugUnitTest`.
- **Pack rules live twice:** `pack_period.dart` (UI) and `PackMath.kt` (background alerts). Change both, with tests on both sides.
- **Generated code:** only `lib/l10n/app_localizations*.dart` (`flutter gen-l10n`).
- **Supported:** Android 8.0 (API 26) and later.

When existing code disagrees with these rules, **follow the existing code in that file** and mention the difference. Don't refactor unrelated code.

## Before you finish any change

Run these and fix everything they report. A change isn't done until all three pass.

```bash
dart format .
flutter analyze
flutter test
```

- Never silence a lint with `// ignore:` or by editing `analysis_options.yaml` unless the user asks.
- Never edit generated files (`*.g.dart`, `*.freezed.dart`, `lib/l10n/app_localizations*.dart`). Change the source and regenerate.
- Don't add a package without saying why and checking that it's maintained (recent release, null safety, supports our platforms). Prefer the SDK and existing dependencies.
- Don't change `pubspec.lock`, platform folders (`android/`, `ios/`) or CI files unless the task needs it.

## Architecture

- **Layers:** `presentation` (widgets, controllers) → `domain` (models, repository interfaces) → `data` (API clients, databases, repository implementations). Imports only point inwards: widgets never import `data/` (controllers reach repositories through their providers), and `domain/` imports nothing from Flutter or `data/`.
- **Repositories are interfaces** in `domain/`, implemented in `data/`, provided through Riverpod. Tests replace them with fakes.
- **Models are immutable:** `final` fields, `const` constructors, `copyWith`, value equality. Use `sealed` classes for states and results so `switch` is exhaustive.
- **No business logic in widgets.** Widgets render state and forward user intent to a controller. Formatting for display is fine; deciding what happens is not.
- **Money is an integer of minor units** (paise, cents), never `double`.
- **Time:** store `DateTime` in UTC (`toUtc()`); convert to local only for display.

## State management (Riverpod 3)

- One controller per screen or flow: `Notifier<T>` for synchronous state, `AsyncNotifier<T>` when loading is involved.
- Read with `ref.watch` in `build`, `ref.read` in callbacks. Never `ref.read` inside `build`.
- Expose `AsyncValue` and handle all three cases in the UI with `switch`: data, loading, error. Every screen has a real loading state and a real error state with a retry.
- After an `await` in a notifier, check `ref.mounted` before touching `state`.
- Keep providers `final` and top-level. Use `.family` for parameters, not global mutable variables.

## Widgets

- Prefer `StatelessWidget` and small widgets in their own classes over helper methods that return widgets.
- Use `const` constructors wherever possible.
- **No hard-coded colours, text styles or strings.** Use `Theme.of(context).colorScheme`, `textTheme`, and the app's localisations (`AppLocalizations.of(context)`).
- Lists of unknown length use `ListView.builder` (or slivers) with stable `Key`s from the item IDs.
- **`BuildContext` across async gaps:** after `await`, check `if (!context.mounted) return;` before using `context`.
- Dispose every `TextEditingController`, `AnimationController`, `ScrollController`, `FocusNode` and `StreamSubscription` you create.
- Layouts must work from 320 px wide to tablets, and with system text scaled to 200%. Use `Flexible`/`Expanded`, `Wrap` and `LayoutBuilder` instead of fixed sizes.

## Accessibility

- Every tappable element is at least 48×48 dp and has a label (`tooltip` on `IconButton`, `semanticLabel` on meaningful images, `Semantics` for custom controls).
- Decorative images use `excludeFromSemantics: true`.
- Don't convey information by colour alone. Text contrast at least 4.5:1.

## Async, errors and networking

- Data layer methods throw **typed exceptions** (or return a sealed `Result`). Map HTTP status codes and `SocketException`/`TimeoutException` to them in one place. Never show raw exception text to users.
- Every network call has a **timeout**. Retry only idempotent requests, with backoff.
- Never `catch (e) {}` silently. Either handle it, rethrow it, or log it with the stack trace.
- Heavy CPU work (large JSON, image processing, crypto) goes to `Isolate.run` / `compute`.
- Don't use `print`. Use the project's logger, and never log tokens, passwords, OTPs, card or ID numbers, or health data.

## Security

- No secrets in the repository or in Dart code: API keys for paid services belong on a server. Configuration comes from `--dart-define-from-file`, not committed `.env` files.
- Tokens and credentials go in `flutter_secure_storage` (Keychain / Keystore), never `SharedPreferences`.
- Validate deep links and push payloads before acting on them.
- Release builds use `--obfuscate --split-debug-info=<dir>`; keep the symbols for crash reports.

## Testing

- **Unit tests** for controllers, repositories, parsers and anything with branches. **Widget tests** for each screen's loading, data, empty and error states. **Golden tests** only where layout is the point.
- Use **fakes** (small hand-written classes implementing the repository interface) over mocks when the interface is small. Use `mocktail` when you need to verify calls.
- Override providers with `ProviderScope(overrides: [...])` or `ProviderContainer.test(overrides: [...])`.
- Find widgets by `Key` or by user-visible text/semantics, not by widget type when several exist.
- Avoid `pumpAndSettle` with infinite animations (progress indicators). Use `pump()` with a duration.
- Tests must not touch the real network, clock or file system. Inject them.
- When fixing a bug, first write a test that fails because of the bug.

## Performance

- Keep `build` methods cheap: no parsing, sorting large lists, or I/O.
- Split widgets so a state change rebuilds the smallest subtree; use `select` to watch part of a provider.
- Size images to their display size (`cacheWidth`/`cacheHeight`, or a resized URL from the server).
- Avoid `Opacity`, `ClipPath` and `saveLayer`-heavy effects on animated or scrolling content; prefer `FadeTransition`, `AnimatedOpacity`, or colours with alpha.
- Animations that loop forever must stop when off screen or after a few repetitions.
- Judge performance in **profile mode on a real, low-end device**, never in debug mode.

## Git

- Small commits with messages in the imperative ("Add expense list empty state").
- Don't commit build output, `.env` files, keystores or `google-services.json` for production.
