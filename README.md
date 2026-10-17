# Argon release configuration

This branch, `rel-config`, is the working branch for Argon's release metadata and release-configuration documents.

## Files

- `latest.json` — latest stable app version and release notes URL.
- `docs/LATEST-JSON-SCHEMA.md` — JSON schema contract and version comparison rules.
- `docs/RELEASE-CONFIGURATION.md` — workflow for preparing a release metadata change.

The initial version is `0.1.0`. Versions use exactly three numeric components (`MAJOR.MINOR.PATCH`), compared as integers rather than strings. Package URLs and package hashes are intentionally absent until the actual update-package pipeline is ready.

## Editing the latest version

Make release-metadata changes on this branch. Validate the format and ensure that a version is not advertised before its release is ready. Keep `latest.json` compatible with the parser and schema validation in `argon.app`'s `development` branch.

## Access limitation

This repository is private, so Argon clients cannot fetch its raw `latest.json` anonymously. Never embed a GitHub personal access token in the app. Before production, expose the metadata through an endpoint accessible to end users or implement a secure service.
