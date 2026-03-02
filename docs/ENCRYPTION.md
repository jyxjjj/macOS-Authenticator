# Encryption Details

## Algorithm

**AES-256-GCM** (Galois/Counter Mode) as implemented by Apple's `CryptoKit` framework.

- Key size: 256 bits (32 bytes)
- Nonce size: 96 bits (12 bytes), generated fresh for each encrypt operation
- Authentication tag: 128 bits (16 bytes), appended to ciphertext

## Storage Layout

### Per-entry (SQLite columns)

| Column | Content |
| --- | --- |
| `encrypted_secret` | ciphertext \|\| tag (variable length + 16 bytes) |
| `nonce` | 12-byte random nonce |

The nonce is stored separately so it can be fetched alongside the ciphertext without any parsing.

### Export File

```plain
Offset  Length  Content
0       12      Random AES-GCM nonce
12      N       AES-GCM ciphertext (JSON payload) + 16-byte tag
```

## Key Derivation

```swift
let keyBytes = SHA256.hash(data: Data(password.utf8))
let key      = SymmetricKey(data: Data(keyBytes))  // 32 bytes
```

SHA-256 produces a deterministic 32-byte key from any password. **Note:** this is a single-round hash with no salt or stretching. See [SECURITY.md](SECURITY.md) for the implications.

## Encrypt Operation

```swift
let nonce     = AES.GCM.Nonce()                          // 12 random bytes
let sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
// sealedBox.combined = nonce(12) | ciphertext | tag(16)
let stored = Data(sealedBox.combined!.dropFirst(12))     // ciphertext + tag
let nonceData = Data(nonce)
```

## Decrypt Operation

```swift
let nonce     = try AES.GCM.Nonce(data: nonceData)       // 12 bytes from storage
let ciphertext = encrypted.dropLast(16)
let tag        = encrypted.suffix(16)
let sealedBox  = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
let plaintext  = try AES.GCM.open(sealedBox, using: key)
```

Any modification to the ciphertext, nonce, or tag causes `AES.GCM.open` to throw `CryptoKitError.authenticationFailure`.

## Nonce Generation

`AES.GCM.Nonce()` calls `SecRandomCopyBytes` internally, producing a cryptographically random 12-byte nonce. Nonces are never reused because a fresh nonce is generated for each encrypt call (each entry addition and each key rotation).
