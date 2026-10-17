# Argon release metadata schema

The canonical file is `latest.json`. For now the version format is exactly three numeric components: `MAJOR.MINOR.PATCH`.

Example:

```json
{
  "schemaVersion": 1,
  "product": "Argon",
  "channel": "stable",
  "version": "0.1.0",
  "releaseNotesUrl": "https://github.com/ananas123123/argon.app/releases"
}
```

## Fields

- `schemaVersion`: integer schema revision. Initial value: `1`.
- `product`: must be `Argon`.
- `channel`: currently `stable`. Additional channels require an explicit schema/behavior decision.
- `version`: strict `x.x.x` semantic version. Each component is a non-negative integer; leading zeros are rejected except for the component `0`.
- `releaseNotesUrl`: HTTPS link to release notes.

The manifest intentionally does not include a download package yet. Download URLs, package hashes and signed release metadata will be added when package publishing and the updater are implemented.

## Comparison rule

Versions are parsed into three integer components and compared numerically from left to right. They are never sorted or compared as strings.

Examples:

- `1.0.0 < 1.1.0`
- `1.9.0 < 1.10.0`
- `1.10.0 < 2.0.0`
- `1.2.3 = 1.2.3`

Invalid versions must fail validation and must not be silently treated as `0.0.0`.

## Security and hosting

The file is metadata, not proof of publisher identity. When package updates are implemented, the updater must verify signed release metadata. A plain SHA-256 value alone is not an authenticity guarantee if the package and metadata can both be replaced.

The `argon.updater` repository is private. An ordinary installed Argon application cannot fetch this file anonymously from GitHub. Do not put a personal access token or other private credential in the application. Before shipping live update checks, serve equivalent metadata from a public endpoint or design a secure authenticated service that does not distribute a reusable secret to every client.
