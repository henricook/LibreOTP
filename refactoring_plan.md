# LibreOTP Refactoring Plan

## Current Issues

1. **Monolithic Structure**: The `dashboard.dart` file (496 lines) handles too many responsibilities
2. **Redundant Imports**: Same imports duplicated across files
3. **Missing Architecture**: No separation between data, business logic, and UI
4. **No State Management**: Using direct state manipulation
5. **No Data Models**: Data represented as raw maps instead of typed models

## Proposed Directory Structure

```
lib/
├── config/             # App configuration, constants
├── data/
│   ├── models/         # Data models (OtpService, Group)
│   └── repositories/   # Data storage operations
├── domain/
│   └── services/       # Business logic (OtpGenerator)
├── presentation/
│   ├── pages/          # Full screens
│   ├── widgets/        # Reusable UI components
│   └── state/          # State management
└── utils/              # Helper functions
```

## Key Refactoring Tasks

1. **Create Data Models**
   - Create `OtpService`, `Group`, `OtpConfig` classes
   - Replace Map usage with proper typed models

2. **Extract Business Logic**
   - Move OTP generation to separate service
   - Extract search and filtering logic
   - Create clipboard management utility

3. **Break Down UI Components**
   - Split dashboard into smaller widgets:
     - SearchBar
     - OtpTable
     - GroupHeader
     - ServiceRow
     - NotificationToast

4. **Implement State Management**
   - Add Provider/Riverpod for state management
   - Create OtpState class to manage data and UI state

5. **Improve Data Storage**
   - Enhance error handling
   - Add proper data loading/saving with models

## Additional Improvements

- Add error handling with user-friendly messages
- Implement proper logging
- Add unit and widget tests
- Improve responsive design
- Secure OTP secrets in storage
- Prepare for dark mode support
- Clean up unused dependencies and imports

## Timeline

1. Create models and repositories
2. Extract business logic to services
3. Break down UI components
4. Implement state management
5. Add tests and polish