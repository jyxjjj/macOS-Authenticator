# Security Model

## Trust Boundaries

| Boundary | Description |
| --- | --- |
| User ↔ App | Master password entered at unlock |
| App ↔ Keychain | 32-byte master key stored via Security framework |
| App ↔ SQLite | Only ciphertext+nonce stored; plaintext never written |
| App ↔ Filesystem | Export file is encrypted before writing |

## Master Key

The master key is a 32-byte value derived from the user's master password via SHA-256:

```plain
masterKey = SHA256(UTF8(password))   →   SymmetricKey(32 bytes)
```

The derived key is stored in the macOS Keychain under `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, meaning it is:

- Encrypted by the macOS Secure Enclave/Data Protection key
- Only accessible when the device is unlocked
- Not backed up to iCloud or transferred to other devices

The key is **never written to disk** in any other form. In memory it exists only as a `CryptoKit.SymmetricKey` value, which is zeroed on deallocation. Calling `AppState.lock()` clears the reference.

## TOTP Secret Storage

Each TOTP secret is individually encrypted with AES-256-GCM before being written to SQLite:

```plain
plainSecret (bytes from Base32 decode)
  → AES.GCM.seal(plainSecret, key: masterKey, nonce: random12Bytes)
  → encryptedSecret (ciphertext + 16-byte authentication tag)
  → stored in totp_entries.encrypted_secret + totp_entries.nonce
```

The authentication tag guarantees that any tampering with the database is detected immediately.

## Export File Security

Export files use the same master key and AES-256-GCM:

```plain
File = nonce(12 bytes) || AES-GCM(JSON payload, masterKey, nonce)
```

The JSON payload contains the magic header `"NACOS-AUTH-v1"` which is authenticated by the GCM tag. An attacker who obtains an export file cannot read or modify it without the master key.

## What Is NOT Protected

- **Metadata** — Service names and usernames are stored unencrypted in SQLite. An attacker with filesystem access can read these.
- **Timing side channels** — The SHA-256 key derivation has no iteration count / PBKDF2 stretching. This makes offline brute-force faster for weak passwords. Use a strong, unique password.
- **Memory scrubbing** — Swift does not guarantee zeroing of `Data` or `String` objects after use. The `SymmetricKey` type attempts to zero its backing storage on deallocation.
- **Screen capture** — TOTP codes displayed in the UI are visible to screen-recording software and accessibility APIs.
