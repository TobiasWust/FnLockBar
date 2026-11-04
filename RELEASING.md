# Releasing

```bash
git tag v1.4.0 && git push origin v1.4.0
```

The [release workflow](.github/workflows/release.yml) then builds a universal app, signs and notarizes it (if the secrets below exist), publishes a GitHub release with `FnLockBar.zip` and bumps the Homebrew cask.

## Secrets

All are set on this repo (`gh secret set NAME -R TobiasWust/FnLockBar`, then paste). Missing secrets skip their step.

| Secret | What |
| --- | --- |
| `TAP_TOKEN` | Fine-grained token, *Contents: read and write* on `TobiasWust/homebrew-tap` |
| `DEVELOPER_ID_P12` | Developer ID Application certificate + private key, `.p12`, base64 |
| `DEVELOPER_ID_P12_PASSWORD` | Password chosen when exporting the `.p12` |
| `NOTARY_KEY_P8` | App Store Connect API key, contents of the `.p8` file |
| `NOTARY_KEY_ID` | That key's Key ID |
| `NOTARY_ISSUER_ID` | Issuer ID shown above the key list |

## Setting up notarization (once)

Needs a paid [Apple Developer Program](https://developer.apple.com/programs/) membership.

**1. Developer ID certificate**

1. Keychain Access → menu **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority…** → your email and name, **Saved to disk**.
   (With Xcode instead: Settings → Accounts → **Manage Certificates…** → **+** → Developer ID Application, then skip to step 3.)
2. [developer.apple.com → Certificates → +](https://developer.apple.com/account/resources/certificates/add) → **Developer ID Application** (profile type *G2 Sub-CA*) → upload the request → download the `.cer` and double-click it.
   Check: `security find-identity -v -p codesigning` lists *Developer ID Application: …*.
3. Keychain Access → *My Certificates* → right-click **Developer ID Application: …** → **Export…** → save as `.p12` with a password.
4. Store it:

   ```bash
   base64 -i ~/Desktop/DeveloperID.p12 | gh secret set DEVELOPER_ID_P12 -R TobiasWust/FnLockBar
   ```

   ```bash
   gh secret set DEVELOPER_ID_P12_PASSWORD -R TobiasWust/FnLockBar
   ```

5. Delete the exported `.p12` file.

**2. Notary API key**

1. [App Store Connect](https://appstoreconnect.apple.com/access/integrations/api) → Users and Access → Integrations → **App Store Connect API** → **+**, access: **Developer**.
2. Download the `.p8` (only possible once) and note the **Key ID** and **Issuer ID**.
3. Store them:

   ```bash
   gh secret set NOTARY_KEY_P8 -R TobiasWust/FnLockBar < ~/Downloads/AuthKey_XXXXXXXXXX.p8
   ```

   ```bash
   gh secret set NOTARY_KEY_ID -R TobiasWust/FnLockBar
   ```

   ```bash
   gh secret set NOTARY_ISSUER_ID -R TobiasWust/FnLockBar
   ```

4. Keep the `.p8` somewhere safe (e.g. your password manager), then delete the download.

**Test without releasing:** Actions → Release → **Run workflow** builds, signs and notarizes, and attaches the zip as a build artifact instead of publishing it.
