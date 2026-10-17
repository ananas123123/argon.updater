# Argon updater center

This private repository holds Argon's release configuration and, in future, the update tooling.

## Current metadata

- `latest.json` is the initial stable release metadata document.
- Current baseline version: `0.1.0` (strict `MAJOR.MINOR.PATCH`).
- The `rel-config` branch is used to prepare release-metadata changes and maintain the schema/workflow documentation.
- Schema and release procedure: see `docs/LATEST-JSON-SCHEMA.md` and `docs/RELEASE-CONFIGURATION.md` on `rel-config`.

## Important access limitation

This repository is private. A normal installed Argon application cannot anonymously download `latest.json` from GitHub's raw-content endpoint. Do not embed a personal access token in Argon. Before production update checks are enabled, metadata must be served through an endpoint accessible to intended users or through a secure service that does not distribute reusable credentials.

The current versioning implementation in `argon.app` validates three numeric version components and checks metadata structure. Package downloading and installation are not implemented by this metadata file.
