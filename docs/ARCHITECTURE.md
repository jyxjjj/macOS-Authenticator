# Architecture

## Overview

macOS Authenticator is structured as a single-target SwiftUI macOS app with a unit-test target. All code is plain Swift with no external package dependencies; only Apple system frameworks are used.

```
macOS-Authenticator/
├── macOS_AuthenticatorApp.swift   — App entry point (@main)
├── AppState.swift                 — Central ObservableObject; auth + business logic
├── Models/
│   └── TOTPEntry.swift            — Core data model
├── TOTP/
│   ├── TOTPEngine.swift           — RFC 6238 TOTP + otpauth:// URI parser
│   └── Base32Decoder.swift        — RFC 4648 Base32 decoder
├── Crypto/
│   └── AESCryptoManager.swift     — AES-256-GCM encrypt/decrypt (CryptoKit)
├── Keychain/
│   └── KeychainManager.swift      — Keychain read/write for master key
├── Database/
│   └── DatabaseManager.swift      — SQLite3 CRUD (built-in macOS library)
└── Views/
    ├── ContentView.swift           — Root switcher (locked ↔ unlocked)
    ├── MasterPasswordView.swift    — Login / first-launch setup
    ├── TOTPListView.swift          — Main list with search + toolbar
    ├── TOTPRowView.swift           — Individual row with live countdown
    ├── AddEntryView.swift          — Add account (manual / URI)
    ├── EditEntryView.swift         — Edit account metadata
    ├── SettingsView.swift          — Change master password + about
    └── ExportImportView.swift      — Encrypted backup export/import
```

## Module Responsibilities

### AppState
`@MainActor final class AppState: ObservableObject`

Central state manager injected via `@EnvironmentObject`. Responsibilities:
- Holds the in-memory `SymmetricKey` (cleared on lock)
- Manages `isLocked` published state
- Wraps `DatabaseManager` for CRUD
- Implements master key derivation, unlock/lock, and key rotation
- Provides `exportData()` / `importData()` for backup

### TOTPEngine
Pure static struct. Given a `Data` secret, `TOTPAlgorithm`, digit count, and period, computes HOTP/TOTP per RFC 6238. Also parses `otpauth://totp/...` URIs.

### Base32Decoder
Pure static struct implementing RFC 4648 §6 Base32 decoding. Strips padding and whitespace before decoding.

### AESCryptoManager
Pure static struct wrapping `CryptoKit.AES.GCM`. Each encrypt call generates a fresh random 12-byte nonce. The nonce is returned separately from the ciphertext+tag blob so they can be stored independently in SQLite.

### KeychainManager
Static struct using `Security.framework` `SecItem*` APIs. Stores a single 32-byte master key under `kSecClassGenericPassword` with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

### DatabaseManager
`final class DatabaseManager`. Opens/creates `~/Library/Application Support/com.desmg.nacos.authenticator/entries.db`. All secrets are stored as encrypted blobs; the database never holds plaintext. `replaceAll()` uses a SQLite transaction for atomic key rotation.

## Data Flow

### Unlock
```
User password → SHA256 → SymmetricKey (candidate)
Keychain → stored key bytes
candidate == stored ? → set masterKey in AppState, unlock
```

### Code Generation
```
TOTPRowView (Timer 1s) → AppState.decryptSecret(entry)
  → AESCryptoManager.decrypt(encryptedSecret, nonce, masterKey) → secretData
  → TOTPEngine.generateCode(secretData, algorithm, digits, period) → "123456"
```

### Add Entry
```
User input (Base32 string) → Base32Decoder.decode → secretData
AESCryptoManager.encrypt(secretData, masterKey) → (enc, nonce)
TOTPEntry(encryptedSecret: enc, nonce: nonce, ...)
DatabaseManager.insert(entry)
```

### Key Rotation
```
Verify old password → derive oldKey / newKey
For each entry: decrypt(enc, nonce, oldKey) → plain → encrypt(plain, newKey) → (newEnc, newNonce)
DatabaseManager.replaceAll(reEncrypted entries)   [atomic transaction]
KeychainManager.saveMasterKey(newKeyData)
```
