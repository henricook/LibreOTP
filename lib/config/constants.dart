// File paths and names
const String kFolderName = 'LibreOTP';
const String kDataFileName = 'data.json';

// UI Constants
const double kHeaderHeight = 40.0;
const double kRowMinHeight = 28.0;
const double kRowMaxHeight = 28.0;
const double kDividerThickness = 0.5;
const int kSnackbarDurationSeconds = 2;
const double kDefaultPadding = 8.0;
const double kDefaultMargin = 16.0;
const double kIconSize = 24.0;
const double kLargeIconSize = 60.0;

// Table Columns
const String kNameColumn = 'Name';
const String kAccountColumn = 'Account';
const String kIssuerColumn = 'Issuer';
const String kOtpValueColumn = 'OTP Value';
const String kValidityColumn = 'Validity';
const String kUnknownGroupName = 'Unknown Group';

// Storage keys
const String kServicesKey = 'services';
const String kGroupsKey = 'groups';
const String kUpdatedAtKey = 'updatedAt';

// OTP Constants
const String kDefaultAlgorithm = 'SHA1';
const int kDefaultDigits = 6;
const int kDefaultPeriod = 30;

// Default group names
const String kUngroupedName = 'Ungrouped';
const String kUngroupedId = 'Ungrouped';

// Messages
const String kErrorLoadingData = 'Error loading data';
const String kErrorSavingData = 'Error saving data';
const String kFileNotFound = 'Data file not found';
const String kOtpCopiedMessage = 'OTP Code Copied to Clipboard!';
const String kErrorGeneratingOtp = 'Failed to generate OTP code';
const String kRefreshDataLabel = 'Refresh Data';
const String kRetryLabel = 'Retry';
const String kViewDataDirectoryLabel = 'View Data Directory';
const String kShowDataDirectoryLabel = 'Show Data Directory';
const String kAboutLabel = 'About';

// Timer constants
const int kOneSecondInMillis = 1000;