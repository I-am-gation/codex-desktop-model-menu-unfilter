# Changelog

## 1.0.1 - 2026-07-10

- Added source and patched ASAR hash fingerprints so Store updates and damaged copies are rebuilt reliably.
- Added a restart prompt when an outdated patched copy is still running.
- Added explicit Windows UI-language forwarding and a verified i18n startup-default patch.
- Added strict unique-target, byte-length, and post-write patch verification.
- Fixed launcher recovery when the patched directory is missing or a directory swap was interrupted.
- Prevented concurrent launcher instances from racing the same update transaction.
- Disabled the copied app's unusable MSIX updater and report immediate startup exits instead of failing silently.
- Added explicit silent/forced uninstall switches for automated clean-install verification.
- Fixed uninstall cleanup for orphaned bundled helper processes whose executable path is hidden by WMI.
- Fixed desktop and Start menu shortcuts to use the installed Codex application icon.
- Added a local Windows launcher self-test.

## 1.0.0 - 2026-07-10

- Initial public release.
- Added exact-length ASAR model-menu unfilter patch.
- Added transactional staging and rollback for Codex Desktop updates.
- Added Microsoft Store Codex process detection that does not target the separate ChatGPT app.
- Added local launcher compilation, desktop and Start menu shortcuts, repair, and uninstall flows.
- Added Chinese installation, checksum, troubleshooting, privacy, and compatibility documentation.
