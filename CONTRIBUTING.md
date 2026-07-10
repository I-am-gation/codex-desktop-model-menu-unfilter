# Contributing

Bug reports and focused compatibility fixes are welcome.

Before opening an issue:

1. Update the Microsoft Store Codex app.
2. Run `Repair-or-Update.cmd` from the matching release.
3. Confirm the problem occurs in the patched copy rather than the official Store app.
4. Remove personal information from logs and screenshots.

Pull requests should keep the patch reversible, verify exact and unique patch targets, preserve the official Store package, and include a clear failure path for incompatible Codex versions.

Do not commit Codex binaries, official assets, API keys, tokens, model-provider credentials, personal configuration, or code intended to bypass account or model access controls.
