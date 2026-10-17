# Argon release configuration workflow

## Source of truth

- `latest.json` on `main` is the base copy.
- The `rel-config` branch is the working branch for release metadata and related documentation.
- Keep the schema compatible with the version parser in `argon.app`'s `development` branch.
- Update `version` only when a release decision is made. Current baseline: `0.1.0`.

## Release metadata change checklist

1. Choose a new `MAJOR.MINOR.PATCH` version.
2. Validate that it contains exactly three numeric components and no leading zeros (except the value `0`).
3. Update `latest.json` on `rel-config`.
4. Ensure the package and release notes exist before advertising a new version as downloadable.
5. Review the metadata diff and confirm `product`, `channel`, `version` and HTTPS `releaseNotesUrl`.
6. Later, when updates are enabled, publish signed metadata and verify package integrity/authenticity before installation.

## Initial state

The current metadata advertises version `0.1.0`, matching the initial app version configured in `argon.app`. There is no package URL yet because this phase implements version identity and update discovery only.

## Private-repository limitation

GitHub's raw-content URL for this private repository is not anonymously readable by a normal installed Argon app. The app code must not embed a GitHub token. Before a production release, move or serve the metadata through an endpoint accessible to end users, or design a backend that safely mediates access. The app's configured URL can be overridden with `ARGON_LATEST_JSON_URL` for development/testing, but this does not bypass private-repository permissions.
