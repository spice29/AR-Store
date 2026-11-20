# ABUREMAS Ad Hoc OTA distribution

This repo includes `tools/create_ota_manifest.py` for **already signed** Ad Hoc IPA files. It generates a valid XML `manifest.plist` and a small Arabic Safari install page.

## Prerequisites
- The target device UDID is present in the app's Ad Hoc provisioning profile. The profile's App ID must match the IPA bundle ID and its signing certificate must be valid.
- Sign the IPA locally with the user's P12 and matching provisioning profile. Do not commit certificates, passwords, provisioning files or signed IPAs to GitHub.
- Host signed IPA and manifest on trusted HTTPS with stable, reachable URLs. Apple's installation service must be able to fetch both assets; a five-minute expiring URL is not reliable for an installation workflow.
- Users must be authorized to access the installation page and files. Use a secure delivery service and revoke access when needed. A publicly accessible unguessable URL is not equivalent to authentication.

## Generate installation files
```bash
python3 tools/create_ota_manifest.py \\
  --ipa-url 'https://YOUR-DOMAIN.example/releases/MyApp.ipa' \\
  --manifest-url 'https://YOUR-DOMAIN.example/releases/manifest.plist' \\
  --bundle-id 'com.example.myapp' \\
  --version '1.0' \\
  --title 'My App' \\
  --output dist
```

Upload `dist/manifest.plist` and `dist/index.html` beside the signed IPA to your HTTPS host, preserving the URL passed above. Open `index.html` in Safari on a registered device and tap **تثبيت التطبيق**.

## Important scope
The store's current private-bucket signed URL is a **download** feature, not an OTA installer. Do not present it as an install action. An authenticated, long-enough-lived OTA delivery backend is still required for in-app installation, and the device test must pass before production readiness is claimed. Apple documents Ad Hoc distribution only for registered devices.
