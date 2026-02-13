# Chronote CLI Productization Plan

## Goal

Ship a standalone executable `chronote-cli` alongside the GUI app so agents can read Chronote data without coupling to app lifecycle.

## Principles

1. CLI is a separate process from GUI app.
2. CLI is read-only against Chronote's local store by default.
3. Output is machine-readable JSON.
4. Distribution must include arm64, x86_64, and universal artifacts.
5. MCP support should be layered on top of the same query core.

## Architecture

### Components

1. `chronote` (GUI app)
2. `chronote-cli` (standalone executable, Swift Package at `cli/`)
3. Shared datastore: `~/Library/Application Support/time-trace.store`

### Current CLI Commands

1. `help`
2. `projects`
3. `activities`
4. `events`
5. `summary`

### Data Contract

1. JSON only
2. ISO-8601 timestamps
3. Stable field names for agent parsing
4. Explicit `count` and query window metadata

## Build and Packaging

### Build Flow

1. Build CLI per architecture: arm64 and x86_64
2. Merge to universal via `lipo`
3. Build app per architecture/universal
4. Include matching `chronote-cli` binary in each DMG staging directory

### Scripts

1. `scripts/build-chronote-cli.sh`
2. `package.sh` invokes the CLI build script before DMG creation

## Release Strategy

### Versioning

1. App version remains source of truth.
2. CLI version should match app version in release notes and artifacts.
3. Any breaking JSON change requires explicit migration note.

### Distribution

1. DMG contains `chronote.app`
2. DMG also contains `chronote-cli`
3. Optional future installer step: copy CLI to `/usr/local/bin/chronote-cli`

## Compatibility Guarantees

1. Keep command names stable.
2. Add fields in a backward-compatible way.
3. Avoid removing or renaming existing top-level keys without a major version bump.

## Security and Privacy

1. CLI defaults to read-only behavior.
2. No network calls required for data retrieval.
3. Data stays local unless user explicitly pipes or exports results.

## MCP Roadmap

### Phase 1 (Current)

1. Standalone JSON CLI
2. Suitable for wrapper-based MCP adapters

### Phase 2

1. Add `chronote-cli mcp-stdio` mode
2. Implement `tools/list` and `tools/call` over stdio JSON-RPC
3. Reuse current query functions to avoid duplicated logic

### Phase 3

1. Add auth and permission gates for sensitive fields
2. Add capability/version handshake for clients

## Operational Quality Gates

1. Build gate: app + CLI both compile in CI
2. Smoke tests:
   1. `chronote-cli help`
   2. `chronote-cli projects`
   3. `chronote-cli summary --date <today>`
3. Schema sanity test: fail with clear message if required SQLite tables are missing

## Next Tasks

1. Add CLI unit tests for argument parsing and timestamp conversion.
2. Add JSON schema snapshots for command outputs.
3. Add `mcp-stdio` subcommand based on the same query layer.
