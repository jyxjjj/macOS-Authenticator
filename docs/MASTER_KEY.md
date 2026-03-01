# Master Key Lifecycle

## Key Derivation

The master key is derived from the user's master password on every unlock:

```
masterKey = SymmetricKey(data: SHA256(UTF8(password)))
```

This is a **deterministic** operation — the same password always produces the same key. There is no salt, so rainbow-table attacks are theoretically possible against weak passwords. Use a strong, unique password.

## First Launch

1. User enters a password and confirmation in `MasterPasswordView`.
2. `AppState.setupMasterPassword(_:)` calls `deriveKey(from:)` to produce the 32-byte key.
3. The key bytes are written to the Keychain via `KeychainManager.saveMasterKey(_:)`.
4. The `SymmetricKey` is stored in `AppState.masterKey` (memory only).
5. `isLocked` transitions to `false`.

## Normal Unlock

1. User enters password in `MasterPasswordView`.
2. `AppState.unlock(password:)` derives the candidate key.
3. The candidate key bytes are compared against the bytes loaded from the Keychain.
4. If they match, `masterKey` is set and `isLocked` = `false`.
5. All entries are loaded from SQLite into `entries`.

## Lock

Calling `AppState.lock()`:
- Sets `masterKey = nil` (the `SymmetricKey` value is dropped; CryptoKit zeroes the backing memory)
- Sets `isLocked = true`
- Clears `entries = []`

## Password Change (Key Rotation)

`AppState.changeMasterPassword(oldPassword:newPassword:)`:

1. Load stored key from Keychain; verify `deriveKey(old)` matches.
2. Compute `newKey = deriveKey(new)`.
3. For each entry in the database:
   - Decrypt `encryptedSecret` with `oldKey`
   - Re-encrypt with `newKey` using a fresh random nonce
4. Call `DatabaseManager.replaceAll(reEncryptedEntries)` — this runs inside a SQLite transaction; if any step fails the database is rolled back.
5. Write `newKey` bytes to the Keychain (overwrites old entry).
6. Set `masterKey = newKey` in memory.

## Keychain Attributes

```swift
kSecClass:          kSecClassGenericPassword
kSecAttrService:    "com.desmg.macos.authenticator"
kSecAttrAccount:    "master-key"
kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
```

`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` means:
- The item is only accessible while the Mac is unlocked.
- The item is **not** included in iCloud Keychain sync or device backups.
- Migrating to a new Mac requires re-entering the master password and re-importing entries.
