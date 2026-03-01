# Threat Model

## Assets

| Asset | Value |
|---|---|
| TOTP secrets (Base32) | High — allows generating valid OTP codes |
| Service names / usernames | Medium — reveals which services the user protects |
| Master password | Critical — controls access to all secrets |
| Export backup file | High — contains all encrypted secrets |

## Threat Actors

| Actor | Capability |
|---|---|
| Passive filesystem observer | Read-only access to `~/Library/Application Support/...` |
| Local attacker (same user session) | Full user-space access, memory inspection |
| Malicious app | Sandboxed apps cannot read other apps' Keychain items |
| Remote attacker | No network attack surface (app is fully offline) |

## Threat Analysis

### T1 — Database file theft (filesystem access)

**Threat:** Attacker copies `entries.db` from Application Support.

**Mitigation:** All `encrypted_secret` columns are AES-256-GCM ciphertext. Without the master key the attacker cannot decrypt them. Service names and usernames are stored in plaintext — these would be disclosed.

**Residual risk:** Metadata (service names, usernames) is exposed. Acceptable for a local-storage authenticator.

---

### T2 — Weak master password / brute force

**Threat:** Attacker steals the database and the Keychain item, then brute-forces the password.

**Mitigation:** SHA-256 key derivation is fast. A weak password (e.g., dictionary word) could be cracked offline.

**Residual risk:** Medium. Users should choose a strong, unique master password. A future improvement would be PBKDF2 or Argon2 key stretching.

---

### T3 — Memory scraping

**Threat:** Attacker dumps process memory while the app is unlocked and extracts the `SymmetricKey`.

**Mitigation:** `CryptoKit.SymmetricKey` zeroes its backing memory on deallocation. However, the key is live in memory while the app is unlocked. An attacker with ptrace/task_for_pid access (requires same UID or root) could read it.

**Residual risk:** Acceptable for a desktop authenticator; mitigated by macOS SIP and process isolation.

---

### T4 — Export file theft

**Threat:** Attacker obtains a `.nacosauth` export file.

**Mitigation:** The file is AES-256-GCM encrypted with the master key. Without the master key it cannot be decrypted or modified (GCM authentication tag prevents undetected tampering).

**Residual risk:** Low, assuming a strong master password.

---

### T5 — Keychain extraction

**Threat:** Attacker extracts the Keychain item directly (e.g., via `security` CLI or keychain dump tool).

**Mitigation:** `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` requires macOS user session to be unlocked. The item is protected by the macOS user's login password. Sandbox entitlements restrict which processes can access the item.

**Residual risk:** If the attacker has the user's macOS login password, they already control the session; this is equivalent to full compromise.

---

### T6 — Screen capture / accessibility APIs

**Threat:** Malicious app reads TOTP codes from the screen via accessibility APIs or screen recording.

**Mitigation:** None in the current implementation. App Sandbox is disabled (required for Keychain + SQLite in Application Support without entitlements complexity).

**Residual risk:** Medium. Users should not run untrusted applications on the same account.

---

### T7 — Supply chain / build tampering

**Threat:** The build process is compromised and a backdoored binary is distributed.

**Mitigation:** GitHub Actions workflow builds from source on a fresh `macos-14` runner on every push. Releases are created directly from CI artifacts. All source is AGPL-3.0 and auditable.

**Residual risk:** Low, assuming GitHub Actions infrastructure is not compromised.

## Out of Scope

- Network attacks (app has no network access)
- Hardware attacks (cold boot, evil maid)
- macOS kernel / firmware vulnerabilities
- Cryptographic weaknesses in AES-256-GCM or SHA-256
