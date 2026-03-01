# macOS Authenticator

A native macOS TOTP (Time-based One-Time Password) authenticator application built with SwiftUI, following RFC 6238 and RFC 4648. All secrets are encrypted at rest using AES-256-GCM with a master password.

## Features

- **RFC 6238 TOTP** — SHA1, SHA256, SHA512 algorithms; configurable digits (6–8) and period (15–60s)
- **RFC 4648 Base32** — Standard Base32 decoder for secret keys
- **AES-256-GCM encryption** — All TOTP secrets are encrypted at rest
- **SQLite3 storage** — Uses macOS's built-in SQLite3 library; no external dependencies
- **Keychain integration** — Master key stored securely in the macOS Keychain
- **Master password management** — Change password with automatic re-encryption of all entries
- **Export / Import** — AES-256-GCM encrypted backup files
- **otpauth:// URI parsing** — Scan/paste URI links from other authenticators
- **Auto-refresh** — Live countdown timer updates codes every second
- **macOS 14.0+ (Sonoma)**

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.3 or later (for building from source)

## Building

```bash
xcodebuild build \
  -project macOS-Authenticator.xcodeproj \
  -scheme macOS-Authenticator \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO
```

## Testing

```bash
xcodebuild test \
  -project macOS-Authenticator.xcodeproj \
  -scheme macOS-AuthenticatorTests \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO
```

## Usage

1. **First launch** — Set a master password (minimum 8 characters). This password is hashed with SHA-256 to derive the AES-256 encryption key stored in the Keychain.
2. **Add account** — Click **+** to add a TOTP account manually (Base32 secret) or by pasting an `otpauth://` URI.
3. **Copy code** — Click the copy icon on any row to copy the current TOTP code.
4. **Export** — Use the export button to save an AES-256-GCM encrypted backup file.
5. **Import** — Import a previously exported backup (only new accounts are added).
6. **Change password** — Open Settings to change the master password; all entries are re-encrypted automatically.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for module descriptions and data flow.

## Security

See [docs/SECURITY.md](docs/SECURITY.md) for the security model and [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md) for threat analysis.

## License

[AGPL-3.0](LICENSE)

**Bundle ID:** `com.desmg.macos.authenticator`
