# Argon release configuration

This branch, `rel-config`, contains Argon's stable-release metadata. It is separate from the native updater implementation.

## Metadata files

- `latest.json` — latest stable Argon application version and release-notes URL. It uses the existing three-part app version format.
- `bootstrap-latest.json` — latest Bootstrap and updater versions, plus the URL for the updater directory metadata. Bootstrap and updater versions use four numeric components.
- `directory.json` — updater package descriptor for the exact version advertised by `bootstrap-latest.json`. It supplies the HTTPS package URL, SHA-256 digest, expected byte size, and minimum Bootstrap version.

The current configuration advertises Bootstrap and updater version `1.0.0.0`. No updater executable has been published yet, so `directory.json` intentionally has an empty `packageUrl`, an empty `sha256`, and `sizeBytes: 0`. Bootstrap must refuse to install or replace an updater until these fields describe a real release asset.

## Release workflow

1. Publish the updater binary as a versioned release asset.
2. Embed the matching four-part Windows file version in the executable's VERSIONINFO resource.
3. Set `packageUrl` to the HTTPS asset URL.
4. Calculate and set the exact SHA-256 and byte size of that asset.
5. Confirm the `updaterVersion` in both JSON files matches, then test installation and rollback in a disposable folder before advertising the package.

Never publish a version before its binary is available. Keep `latest.json` compatible with the existing version parser in `argon.app`'s `development` branch.

The metadata endpoints are intended to be readable by clients without embedded credentials. Never embed a GitHub personal access token in Argon. HTTPS and a checksum protect the transport and detect mismatches; production automatic updates should add signed metadata and/or package-signature verification because an attacker able to change both a package and its checksum could otherwise replace them together.
