# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
LibreOTP is a desktop OTP code generator that works with 2FAS exports. 2FAS is an open-source mobile authentication app with features like account grouping, encrypted backups, and an open export format. LibreOTP brings these codes to desktop environments.

## Build Commands
- Run app: `flutter run`
- Build: `flutter build [linux|macos|windows]`
- Tests: `flutter test` (all) or `flutter test test/widget_test.dart` (single)
- Test with pattern: `flutter test --name="pattern"`
- Coverage: `flutter test --coverage`
- Static analysis: `flutter analyze`
- Format code: `dart format .`

## Code Style Guidelines
- **Imports**: Dart core first, Flutter second, packages third, local last
- **Naming**: PascalCase for classes, camelCase for variables/functions, _prefixForPrivate
- **Formatting**: 2-space indentation, no trailing spaces
- **Linting**: Default Flutter lints (`package:flutter_lints/flutter.yaml`)
- **Error Handling**: Use try/catch for file operations, provide fallbacks for errors
- **Comments**: Prefer self-documenting code; use comments for complex logic

## 2FAS Integration
- 2FAS exports use a JSON format containing service, account and secret information
- The app supports 2FAS groups and service icons
- Currently only unencrypted exports are supported
- Only TOTP (time-based) keys are implemented (not HOTP/counter-based)
- 2FAS services may contain additional metadata that can be leveraged

## Data File Paths
- Windows: `C:\Users\<Username>\Documents\LibreOTP\data.json`
- MacOS: `/Users/<Username>/Library/Containers/com.henricook.libreotp/Data/Documents/LibreOTP/data.json`
- Linux: `/home/<Username>/Documents/LibreOTP/data.json`

## Development Workflow
1. Put a valid `data.json` file in the appropriate location (see paths above)
2. Make code changes and test with `flutter run`
3. Verify formatting and linting before committing
4. For package builds, follow the deb package build steps in README.md

## Future Improvement Areas
- Support for encrypted 2FAS exports (priority)
- Google Drive sync capability
- Better installers for various platforms
- Automated release pipeline