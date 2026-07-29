# Gemvault Implementation Plan

## Context

Bundler supports `path:`, `git:`, and remote sources but not `.gem` files directly. The `bundler-source-package` plugin proves single `.gem` file support works. Gemvault extends this to **multi-gem portable archives** — a single `.gemv` file containing multiple gems, backed by SQLite. Commit it, send it over Slack, reference it in your Gemfile. Like a `.jar` directory but for Ruby.

```ruby
# CLI
gemvault new randomgems                          # creates randomgems.gemv
gemvault add randomgems.gemv foo.gem bar.gem     # add gems
gemvault list randomgems.gemv                    # list contents

# Gemfile
source "randomgems.gemv", type: :vault do
  gem "foo"
  gem "bar"
end
```

## Phase Dependency Graph

```
Phase 1 (Vault lib + tests)
  └──> Phase 2 (Source plugin + tests)    [needs Vault]
           └──> Phase 3 (Integration tests)  [needs Source]
                    └──> Phase 4 (CLI)  [thin wrapper, last]
                              └──> Phase 5 (Encryption)  [future]
```

## SQLite Schema

```sql
CREATE TABLE metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE gems (
  name TEXT NOT NULL,
  version TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'ruby',
  spec TEXT NOT NULL,
  data BLOB NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (name, version, platform)
);
```

## Status

- Phase 0: Complete (project scaffolding)
- Phase 1: Complete (core Vault library — 27 unit tests)
- Phase 2: Complete (Bundler source plugin — 15 unit tests)
- Phase 3: Complete (integration tests — 11 end-to-end tests)
- Phase 4: Complete (CLI tool with CommandKit auto-loaded subcommands — 27 CLI tests)
- Phase 5: Future (encryption)

Post-phase refinements:
- Schema: dropped `spec` column, specs derived from gem blobs at runtime
- Tests: idiomatic Minitest assertions, Pathname throughout
- CLI: refactored from hand-rolled dispatcher to CommandKit::Commands::AutoLoad

Total: 84 tests, 215 assertions
