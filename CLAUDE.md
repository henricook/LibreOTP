# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
LibreOTP is a cross-platform desktop OTP code generator that works with 2FAS exports. 2FAS is an open-source mobile authentication app with features like account grouping, encrypted backups, and an open export format. LibreOTP brings these codes to desktop environments (Windows, macOS, Linux) via Flutter.

## Build Commands
- Run app: `flutter run`
- Build: `flutter build [linux|macos|windows]`
- Tests: `flutter test` (all) or `flutter test test/widget_test.dart` (single)
- Test with pattern: `flutter test --name="pattern"`
- Coverage: `flutter test --coverage`
- Static analysis: `flutter analyze`
- Format code: `dart format .`

## Architecture

The app follows a layered architecture with Provider for state management:

- **`lib/main.dart`** - Entry point. Sets up `ChangeNotifierProvider<OtpState>` and the `MaterialApp` with theme support.
- **`lib/config/app_config.dart`** - App-wide constants (name, GitHub URL, OTP defaults) and theme/version helpers.
- **`lib/data/models/`** - Data models: `OtpService` (2FAS service with OTP config, usage tracking) and `Group` (2FAS grouping).
- **`lib/data/repositories/storage_repository.dart`** - File I/O layer. Reads/writes plaintext `data.json` and the optional encrypted `data.bin` vault (preferred over `data.json` when both exist; saved atomically via temp+backup rename with crash recovery), handles file picker for import, delegates decryption to `TwoFasDecryptionService`/`LocalVaultEncryptionService`. Contains `AppData` wrapper class.
- **`lib/domain/services/otp_service.dart`** - TOTP code generation using the `otp` package.
- **`lib/services/twofas_decryption_service.dart`** - Decrypts 2FAS encrypted exports (PBKDF2 key derivation + AES-GCM). Includes password verification via reference field.
- **`lib/services/local_vault_encryption_service.dart`** - Encrypts/decrypts the local `data.bin` vault (PBKDF2-HMAC-SHA256 at 600k iterations + AES-256-GCM with AAD-bound header; KDF runs in an isolate).
- **`lib/services/crypto_primitives.dart`** - Thin pointycastle wrappers (PBKDF2, AES-GCM) shared by the vault and 2FAS decryption services.
- **`lib/services/secure_storage_service.dart`** - Stores/retrieves 2FAS backup passwords via `flutter_secure_storage` (the local vault password is never persisted).
- **`lib/services/twofas_icon_service.dart`** - Fetches service icons from 2FAS icon repository.
- **`lib/presentation/state/otp_state.dart`** - Central `ChangeNotifier`. Manages services list, groups, search, display modes (grouped vs usage-based), OTP generation with countdown timers, and debounced persistence. This is the core business logic orchestrator.
- **`lib/presentation/state/otp_display_state.dart`** - Immutable state for a single OTP display (code + validity countdown).
- **`lib/presentation/pages/`** - `DashboardPage` (main view), `AboutPage`, `DataDirectoryPage`.
- **`lib/presentation/widgets/`** - UI components: `OtpTable` (sortable columns), `ServiceRow` (right-click context menu with entry editing), `GroupHeader`, `EditServiceDialog`, `SearchBar`, `PasswordDialog`, `NotificationToast`.
- **`lib/utils/`** - Clipboard and JSON utilities.

### Key data flow
1. `StorageRepository` loads from the platform-specific app support directory: encrypted `data.bin` vault first (prompting for its password), otherwise plaintext `data.json`
2. Encrypted 2FAS backups inside `data.json` are decrypted by `TwoFasDecryptionService` using a stored or user-provided password; the `data.bin` vault is decrypted by `LocalVaultEncryptionService`
3. `OtpState` holds parsed services/groups, groups them, handles search filtering
4. On OTP generation: code is generated, copied to clipboard, countdown timer starts, usage stats are updated and debounce-saved (re-encrypted with the cached session key when the vault is active)
5. Users with plaintext data are offered a one-time migration into the encrypted vault; migration verifies the encrypted copy before deleting `data.json`

### Testing patterns
- `OtpState` tests call `await state.initializeData()` manually (auto-init via `WidgetsBinding` is skipped in test environments)
- Tests mirror the `lib/` directory structure under `test/`

## Code Style Guidelines
- **Imports**: Dart core first, Flutter second, packages third, local last
- **Naming**: PascalCase for classes, camelCase for variables/functions, _prefixForPrivate
- **Formatting**: 2-space indentation, no trailing spaces
- **Linting**: Default Flutter lints (`package:flutter_lints/flutter.yaml`)

## 2FAS Integration
- 2FAS exports use a JSON format containing service, account and secret information
- Both encrypted and unencrypted exports are supported
- Encrypted format: `servicesEncrypted` field contains `base64(ciphertext+tag):base64(salt):base64(iv)`
- Decryption: PBKDF2 (SHA256, 10000 iterations) for key derivation, AES-256-GCM for decryption
- Only TOTP (time-based) keys are implemented (not HOTP/counter-based)
- The app supports 2FAS groups and fetches service icons from 2FAS icon repository

## Data File Paths
Plaintext `data.json`, or encrypted vault `data.bin` when local encryption is enabled (`data.bin` wins if both exist):
- Windows: `%APPDATA%\libreotp\`
- macOS: `~/Library/Application Support/com.henricook.libreotp/`
- Linux: `~/.local/share/libreotp/`

## Notable Dependencies
- `flutter_secure_storage` uses a patched fork (`m-berto/flutter_secure_storage` patch-2 branch) via `dependency_overrides` in `pubspec.yaml` to fix Linux compilation issues
- `pointycastle` for AES-GCM decryption and PBKDF2 key derivation

## Building Deb Packages
1. `flutter build linux`
2. Copy `build/linux/x64/release/bundle` to `deb/libreotp_VERSION/opt/libreotp/bundle`
3. Copy `linux/deb-template/usr` to `deb/libreotp_VERSION/usr`
4. Update version in `deb/libreotp_VERSION/DEBIAN/control`
5. `cd deb/ && dpkg-deb --build libreotp_VERSION`