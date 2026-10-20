# Signing, SmartScreen and the free route

State of things as we found them in October 2026 from vendors' own pages. Vendors change prices, regions and rules; check their pages before you decide. No prices are quoted here on purpose.

## The free route: an unsigned ZIP

`scripts/make_zip.ps1` produces `<Product>-<Version>-Windows-x64.zip` holding the `.vst3` bundle folder and a plain read-me, plus a `.sha256` file. There is no installer `.exe`, so there is no installer for SmartScreen to warn about. Users copy the bundle into `C:\Program Files\Common Files\VST3\`. If Windows marks the downloaded ZIP as coming from the internet, right-click the ZIP, Properties, tick **Unblock**, then unzip.

This is good for testers and early adopters. It is not a replacement for signing: antivirus products and Windows Smart App Control can still be unhappy with unsigned, unknown DLLs, and you cannot be certain without real Windows machines. Ask your testers to try a clean, stock Windows 10 and 11 install.

Always publish the SHA-256 next to the download so people can verify it.

## SmartScreen in one paragraph

SmartScreen judges downloaded executables by publisher reputation and by file hash reputation. A new publisher gets warnings for early downloads whichever signing option you pick; reputation builds with downloads. Signing does not remove the warning on day one, it makes the warning name you and lets reputation attach to your identity instead of to each file hash.

## Signing options

- **Azure Artifact Signing** (previously called Trusted Signing). Needs a paid Azure subscription and an identity validation of your organisation (legal name, website and email on the organisation's domain, a business identifier, an address, one representative verified by ID). Our notes say organisations in a short list of countries (US, Canada, EU, UK and a few others), with validation taking 1 to 20 business days; check whether individual developers can now validate. No hardware, no private key to guard, signs from GitHub Actions, short-lived certificates that rotate automatically. No EV tier (not needed for plug-ins).
- **A normal OV code-signing certificate** (SSL.com, DigiCert and others). Since the CA/Browser Forum rules, the private key must live on a hardware token or an HSM, so you cannot keep a `.pfx` in a repository secret. Options are a USB token or the CA's cloud signing service (for example SSL.com eSigner), which also works from CI.

Where signing goes in this workflow: sign the plug-in DLL (and any `.exe`) right after the build and before packaging, and sign the installer `.exe` after `ISCC`. Add the steps behind a condition such as "the signing secrets exist" so unsigned test runs keep working. Verify with `signtool verify /pa`.

## Things to check on real PCs before a public release

Windows 10 and 11, DAWs you claim to support, HiDPI, a machine without administrator rights (does the ZIP route work for users who can copy into the system folder?), and the antivirus that most of your users run.
