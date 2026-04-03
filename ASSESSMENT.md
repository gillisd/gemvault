# Gemvault: Gem Server Without a Server

## The Pitch

Every gem workflow that normally requires running server infrastructure — Geminabox, Gemstash, a private rubygems.org instance — gemvault does with a single SQLite file.

No daemon. No port. No config. No uptime concerns. Just a `.gemv` file you can commit, sync, email, or drop on a USB stick.

## What You Get Today

Three integration layers, all working and tested (122 tests, 0 failures):

```bash
# CLI — manage the vault
gemvault new myvault
gemvault add myvault.gemv rails-7.1.0.gem sidekiq-7.2.0.gem
gemvault list myvault.gemv
gemvault remove myvault.gemv sidekiq
gemvault extract myvault.gemv rails -o vendor/

# Bundler — use in a Gemfile like any source
source "myvault.gemv", type: :vault do
  gem "rails"
  gem "sidekiq"
end

# RubyGems — gem install, no server needed
gem install --source myvault.gemv rails
```

All three participate in real dependency resolution. Platform gems, prereleases, version constraints, lockfiles — it all works.

## Scorecard

| Capability | Status | Notes |
|-----------|--------|-------|
| Store multiple gems in one file | Done | SQLite with ACID guarantees |
| `bundle install` from vault | Done | Full Bundler plugin (source type `:vault`) |
| `gem install --source` from vault | Done | RubyGems plugin, standard install pipeline |
| Dependency resolution | Done | Both Bundler and RubyGems resolvers |
| Platform gems (x86_64, arm64, etc.) | Done | Stored, filtered, resolved correctly |
| Prerelease versions | Done | Filtered by `:released`/`:prerelease`/`:latest` |
| Lockfile generation | Done | Round-trips cleanly |
| Mixed sources (vault + rubygems.org) | Done | Vault gems + public gems coexist |
| Add/remove/list/extract via CLI | Done | 5 commands, all tested |
| Inspectable with standard tools | Done | It's SQLite — `sqlite3 vault.gemv ".tables"` |

## What You Don't Need Anymore

| Before (server) | Now (gemvault) |
|-----------------|----------------|
| Run Geminabox on a VM | Drop a `.gemv` file in your repo |
| Configure Gemstash with Redis | `gemvault new private.gemv` |
| Maintain uptime for CI to pull gems | File is right there on disk |
| Set up auth tokens for private gems | Access = having the file |
| Mirror rubygems.org for air-gapped deploys | `gemvault add` the gems you need |

## Where It Shines

**Air-gapped / offline deploys.** Bundle all your private gems into a `.gemv`, copy it to the isolated network, `bundle install` or `gem install` with no internet.

**CI dependency vendoring.** Commit the `.gemv` alongside your lockfile. CI never hits rubygems.org for your private gems. No gem server to maintain, no tokens to rotate.

**Distributing private gems.** Instead of publishing to a private server, `gemvault add` and hand someone the file. They `gem install --source` and they're done.

**Portable gem snapshots.** Capture a known-good set of gems as a single file. Reproducible installs anywhere, forever, with no network dependency.

## Remaining Gaps

These are real but don't undermine the core proposition:

1. **No update-in-place** — Must `remove` + `add` to replace a version. Could add `--force` flag.
2. **Specs re-extracted on each open** — No cached spec column in SQLite yet. Works fine but adds latency for large vaults.
3. **No `gemvault info`** — No quick way to inspect vault metadata (schema version, created date, total size).
4. **No encryption** — Planned but not implemented. The file is readable SQLite.
5. **Plugin setup friction** — Bundler requires a `plugin` line pointing at the local path until the gem is published to rubygems.org. RubyGems needs `RUBYLIB` set during development.

## Test Coverage

```
122 runs, 0 failures, 0 errors, 0 skips

test/vault_test.rb           — 33 unit tests (Vault CRUD, GemEntry, Vault.open)
test/vault_source_test.rb    — 17 unit tests (Bundler source plugin)
test/cli_test.rb             — 32 CLI tests
test/integration_test.rb     — 12 end-to-end Bundler tests
test/rubygems_plugin_test.rb — 28 RubyGems plugin tests (incl. gem install e2e)
```
