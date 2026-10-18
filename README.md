# Argon release configuration

This branch holds the public stable-release metadata consumed by Argon and its Bootstrap companion.

## Metadata files

- `latest.json` advertises the current Argon application version and its release-notes URL.
- `bootstrap-latest.json` carries compatibility metadata for Bootstrap and, importantly, the published **ArgonUpdater.exe** version in `updaterVersion`.
- `directory.json` describes a downloadable ArgonUpdater.exe package, including its HTTPS URL, exact SHA-256 digest, byte size, and minimum compatible Bootstrap version.

## Version ownership

Bootstrap does **not** compare its own compiled version with `updaterVersion`. It reads the Windows VERSIONINFO file version from the installed `Updater/ArgonUpdater.exe`, fetches `bootstrap-latest.json`, then compares the local updater file version with the `updaterVersion` field. The separate `bootstrapVersion` field describes Bootstrap's compatibility version.

The current target is ArgonUpdater.exe v1.0.0.0. The application repository builds a deliberately inert executable with embedded FileVersion/ProductVersion 1.0.0.0, so the version-reading path can be tested. It contains no update functionality.

No downloadable updater package has been published. Accordingly, `directory.json` intentionally leaves `packageUrl` and `sha256` empty and `sizeBytes` equal to 0. Bootstrap must not install or replace an updater until those fields describe a real release asset. The UI may show a newer advertised version, but an update must remain unapplied until its package is actually available and verified.

## Publishing a real updater

1. Build and test the actual updater executable and embed its intended four-part Windows file version.
2. Publish the binary as a versioned HTTPS release asset.
3. Set `directory.json`'s `packageUrl` to that asset URL, calculate its exact SHA-256 and byte length, and confirm `updaterVersion` matches the executable's embedded version.
4. Set `bootstrap-latest.json`'s `updaterVersion` to the same version and increment `metadataRevision`.
5. Test download, validation, backup, replacement, and rollback inside a disposable Argon-sim directory before advertising the package.

Keep `latest.json` compatible with the three-part Argon application version parser. Public metadata endpoints must be readable without credentials; never embed a GitHub token in the application. HTTPS and a checksum protect transport and catch mismatched files, but a checksum stored beside its URL is not publisher authentication. Production updates should also validate signed packages and/or signed metadata.
