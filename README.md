# LibreOTP

LibreOTP is a cross-platform desktop OTP code generator that works with exported JSON files from [2FAS](https://2fas.com/). It supports Windows, Mac and Linux and 2FAS features like grouping. Both encrypted and unencrypted 2FAS exports are supported. Currently only TOTP keys are supported.

This project was borne from necessity. I needed a modern desktop application that would support 2FAS exports including grouping and search on Linux. It's rough, it's ready, but it does exactly what I needed it to do and might be what you need to!

Flutter means this app works on Windows, Mac and Linux.

Contributions and improvements are welcome, open an `RFC: ` issue if you'd like to discuss a plan before getting started.

## Preview
[Demo Video](https://github.com/user-attachments/assets/2e402b35-34ca-45a0-ab6f-e1dced7e2f6e)

## Getting Started

1. Generate an export from your 2FAS app and download it to your desktop machine, call it `data.json`. 
   - Both encrypted and unencrypted exports are supported
   - For encrypted exports, you'll be prompted to enter your password when the app starts
2. Put this file in a folder called 'LibreOTP' in your system documents directory. This is the hard coded location where the app will search for it e.g. on my linux system that's `/home/henri/Documents/LibreOTP/data.json`. On other platforms the document directory is:
   - Windows: `C:\Users\<Username>\Documents\LibreOTP\data.json`
   - MacOS: `/Users/<Username>/Library/Containers/com.henricook.libreotp/Data/Documents/LibreOTP/data.json` (sorry, MacOS Sandboxing requirements make this ugly. You'll need to create this path.)
   - Linux: `/home/<Username>/Documents`
3. **Linux users only**: Install system dependencies for secure password storage:
   ```bash
   # Ubuntu/Debian - try one of these libjsoncpp versions (varies by Ubuntu version):
   sudo apt install libsecret-1-0 libjsoncpp26  # Ubuntu 24.04+
   # OR
   sudo apt install libsecret-1-0 libjsoncpp25  # Ubuntu 22.04, 23.04
   # OR  
   sudo apt install libsecret-1-0 libjsoncpp1   # Older Ubuntu versions
   
   # For building from source, also install development packages:
   sudo apt install libsecret-1-dev libjsoncpp-dev
   ```
   - These packages enable secure keyring storage of encryption passwords
   - **Note**: The deb package automatically handles version differences
   - **Note**: The app currently uses a patched version of flutter_secure_storage_linux to fix compilation issues on newer Linux distributions

4. Download the appropriate binary/package for your OS from the [Releases page](https://github.com/henricook/libreotp/releases)
   - For source releases: If needed, unpack the zip, it's rough and ready right now but there'll be a folder called 'bundle' in there that you can switch to. On Linux to run the app you'd now do:
      - `chmod +x ./LibreOTP`
      - `./LibreOTP`
   - For the deb: `dpkg -i libreotp_VERSION.deb`, a desktop entry should appear in your launcher

5. Enjoy! And don't forget to :star: Star the repository to encourage further updates. 

## Troubleshooting

### Linux: "Unable to generate build files" or secure storage not working
- If using the deb package: Dependencies should be automatically installed
- If using source/binary releases: Try installing the libjsoncpp version for your Ubuntu:
  - `sudo apt install libsecret-1-0 libjsoncpp26` (Ubuntu 24.04+)
  - `sudo apt install libsecret-1-0 libjsoncpp25` (Ubuntu 22.04/23.04)  
  - `sudo apt install libsecret-1-0 libjsoncpp1` (older versions)
- For development/building: `sudo apt install libsecret-1-dev libjsoncpp-dev`
- **If secure storage compilation fails**: The app will automatically fall back to less secure storage and show a warning message

### "Password required for encrypted backup" error
- Your 2FAS export file is encrypted - this is normal and more secure
- Click "Enter Password" and provide the password you set when creating the export
- The password will be securely stored for future app launches

### Wrong password or decryption errors
- Verify you're using the correct password for your 2FAS export
- If you've forgotten the password, you'll need to create a new export from 2FAS
- Click "Use Different Password" to clear any stored password and try again

### Empty app or no services showing
- Check that your `data.json` file is in the correct location (see file paths above)
- Verify the file contains valid 2FAS export data
- For encrypted files, ensure you've entered the correct password

## Limitations
- Only supports 2FAS export format (not Google Authenticator, Authy, etc.)
- HOTP (counter-based) codes are not yet supported
- File location is hardcoded - no file picker UI
- Linux: secure password storage requires additional system packages (falls back to less secure storage if unavailable)

## Building Deb Packages
1. Run `flutter build linux`
2. Move the contents of `build/linux/x64/release/bundle` to `deb/libreotp_VERSION/opt/libreotp/`
3. Update the version in `deb/libreotp_VERSION/DEBIAN/control` if needed
4. cd to deb/
5. Run `dpkg-deb --build libreotp_VERSION`, the deb appears in the same directory.
6. Install with `sudo dpkg -i libreotp_VERSION.deb`
   - Dependencies (libsecret-1-0, libjsoncpp1) will be automatically installed

## Credit

### [OTPClient](https://github.com/paolostivanin/OTPClient)

Core layout of the app is heavily inspired by `otpclient` which I liked but I found lacked grouping. Being written in C, I didn't find it particularly easy to contribute to either. 

### [Flutter](https://github.com/flutter/flutter) + [GPT4o](https://chat.openai.com)

The Flutter docs are great and along with IntelliJ's starter project meant I got up and running really fast. Coupled with copious amounts of GPTing I went from concept to version 0.1 in just 3 hours with no prior knowledge of Flutter or Dart.

## Features

- ✅ Support for both encrypted and unencrypted 2FAS exports
- ✅ Secure password storage with automatic decryption on subsequent launches
- ✅ Cross-platform support (Windows, macOS, Linux)
- ✅ 2FAS group support and search functionality
- ✅ TOTP code generation with copy-to-clipboard

## Roadmap / ideas

1. Support for HOTP (counter-based) codes
