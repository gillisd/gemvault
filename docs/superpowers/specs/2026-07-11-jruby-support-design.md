# JRuby support via Sequel — design

Date: 2026-07-11
Branch: `jruby-support`
Status: proposed

## Problem

`gemvault` cannot be installed or run on JRuby. The gemspec depends on
`sqlite3 ~> 2.0`, a C-extension gem that cannot build on JRuby, so `bundle
install` fails while compiling the native extension. All SQLite access lives in
`lib/gemvault/vault.rb` and goes through the `sqlite3` gem directly
(`SQLite3::Database`, `SQLite3::Blob`, `results_as_hash`, `execute_batch`,
`changes`).

## Decision

- **Approach: Sequel everywhere.** `Vault` talks to [Sequel](https://sequel.jeremyevans.net/),
  which uses the `sqlite3` C-extension on MRI and the pure-Java `jdbc-sqlite3`
  JDBC driver on JRuby. One code path; the only engine-specific detail is the
  connection, isolated behind a new `Gemvault::Database` seam.
- **Scope: full multi-platform.** Conditional dependencies + a `-java` platform
  gem for publishing + a JRuby CI matrix.

## Evidence (validated on target before committing)

Spike on JRuby 10.1.0.0 (`RUBY_ENGINE=jruby`, `RUBY_VERSION=4.0.0`, platform
`universal-java`, OpenJDK 25):

- `sequel-5.106.0` and `jdbc-sqlite3-3.46.1.1` install with no compilation.
- `Sequel.connect("jdbc:sqlite:PATH")` + `Sequel.blob(bytes)` round-trips all
  256 byte values byte-for-byte (`Sequel::SQL::Blob`, `ASCII-8BIT`).
- A `TEXT ... DEFAULT (datetime('now'))` column returns a `String`.
- `dataset.delete` returns the affected-row count.
- `required_ruby_version >= 3.4.8` is satisfied (JRuby 10.1 reports 4.0.0), so
  **no `required_ruby_version` change is needed**; `RUBY_ENGINE` is the
  discriminator.

## Design

### 1. `Gemvault::Database` — the engine seam (new)

`lib/gemvault/database.rb`. Single responsibility: return a connected
`Sequel::Database` for a vault path, choosing the driver by engine.

```ruby
require "sequel"

module Gemvault
  module Database
    module_function

    def connect(path)
      if RUBY_ENGINE == "jruby"
        require "jdbc/sqlite3"
        Sequel.connect("jdbc:sqlite:#{path}")
      else
        require "sqlite3"
        Sequel.connect(adapter: "sqlite", database: path)
      end
    end
  end
end
```

### 2. `Vault` refactor

`lib/gemvault/vault.rb` stops requiring `sqlite3` and uses Sequel via the seam.
External behavior is unchanged; the existing `test/vault_test.rb` contract must
stay green on both engines. Specific mappings:

| Today (`sqlite3`) | After (Sequel) |
| --- | --- |
| `SQLite3::Database.new(path)` + `results_as_hash = true` | `Gemvault::Database.connect(path)` |
| `execute("... WHERE name = ?", [name])` (SELECT) | `db[:gems].where(name:).all` (symbol keys) |
| `execute(DELETE...)` + `@db.changes` | `db[:gems].where(...).delete` (returns count) |
| `execute("SELECT COUNT(*) ...").first["count"]` | `db[:gems].count` |
| `execute_batch(DDL)` | `db.run(create_metadata_sql)` / `db.run(create_gems_sql)` (schema preserved verbatim) |
| `SQLite3::Blob.new(data)` | `Sequel.blob(data)` |
| `row["data"]`, `row.transform_keys(&:to_sym)` | `row[:data]`, `GemEntry.new(**row)` |

**Close / closed contract (behavioral risk).** Sequel auto-reconnects after
`disconnect`, but `test_open_yields_vault_and_closes` /
`test_open_closes_on_raise` require a post-close query to raise `ArgumentError`,
and `test_close_is_idempotent` requires a second `close` to be a no-op. Preserve
both with a guarded accessor:

```ruby
def close
  return unless @db
  @db.disconnect
  @db = nil
end

private

def db
  @db || raise(ArgumentError, "vault is closed")
end
```

All query methods use `db` instead of `@db`. `validate_sqlite!`, `SQLITE_MAGIC`,
and the create-vs-open guards stay as-is (pure Ruby).

### 3. Gemspec — conditional deps + platform

`gemvault.gemspec`:

```ruby
spec.add_dependency "sequel", "~> 5.0"
if RUBY_ENGINE == "jruby"
  spec.platform = "java"
  spec.add_dependency "jdbc-sqlite3", "~> 3.46"
else
  spec.add_dependency "sqlite3", "~> 2.0"
end
```

`spec.platform = "java"` under JRuby is required so a gem *built* under JRuby is
published as `gemvault-x.y.z-java.gem` (depends on `jdbc-sqlite3`), while a gem
built under MRI stays `gemvault-x.y.z.gem` (depends on `sqlite3`). RubyGems then
serves the correct variant per platform. `sequel` is unconditional.

### 4. Gemfile / lockfile

`Gemfile` keeps `gemspec`. Add the java platform to the committed lock
(`bundle lock --add-platform java`) and regenerate with `sequel` present. CI
installs per engine (non-frozen), so each engine resolves its own driver.
`bundle install` must succeed on JRuby locally as the acceptance for the
reported bug.

### 5. Multi-platform publishing (Rakefile)

Building the `-java` variant requires building under JRuby (that is when the
gemspec sets `platform = "java"`). Plan:

- `rake build` under MRI → `pkg/gemvault-x.y.z.gem`.
- `rake build` under JRuby → `pkg/gemvault-x.y.z-java.gem`.
- Release publishes both. Document the two-engine release in the Rakefile /
  release notes; the CI release path builds each variant on its matching engine.

The `shim/bundler-source-vault` gem has no native code — it only depends on
`gemvault`, which resolves to the right platform variant — so it needs **no**
change and stays platform-agnostic.

### 6. CI (`.github/workflows/ci.yml`)

Add `jruby-10.1.0.0` to the `unit` job matrix, running `bundle install`
(proves the C-extension failure is gone) + `bundle exec rake test` + rubocop.
The container-based `integration` job stays MRI-only (the test container in
`Dockerfile.test` is MRI). Set `JAVA_OPTS=--enable-native-access=ALL-UNNAMED`
for the JRuby job to silence the cosmetic JDBC native-access warning.

## Spec skeleton (specs first)

New RSpec spec for the seam — the engine-agnostic contract a wrong-but-consistent
implementation cannot satisfy (binary integrity, counts, delete-count):

```ruby
# spec/gemvault/database_spec.rb
RSpec.describe Gemvault::Database do
  describe ".connect" do
    it "returns a usable connection that creates the file on first write"
    it "opens an existing database file"
    it "round-trips binary blob data byte-for-byte"
    it "returns a String for a datetime('now') default column"
    it "reports the affected-row count from a delete"
  end
end
```

Regression / acceptance contract (unchanged, must pass on **both** engines):

```
test/vault_test.rb   # full Vault behavior incl. blob round-trip + close contract
```

Integration-level proof of the reported bug (CI job, not RSpec container spec):

```
jruby: bundle install   # succeeds — no sqlite3 C-extension build
jruby: bundle exec rake test   # Vault works end-to-end on JDBC
```

## Verification plan

1. `bundle exec rake test` green on MRI (regression).
2. `bundle exec rake test` green on JRuby (new).
3. `bundle exec rubocop` clean (no `.rubocop.yml` edits, no inline disables).
4. `bundle install` succeeds on JRuby.
5. `rake build` produces `gemvault-x.y.z-java.gem` under JRuby and
   `gemvault-x.y.z.gem` under MRI.

## Risks & mitigations

- **Blob binary integrity on JDBC** — highest risk; validated by spike + covered
  by `database_spec` and `test_gem_data_returns_matching_bytes`.
- **Close/closed semantics under Sequel** — addressed by the guarded `db`
  accessor; covered by existing close tests.
- **Shared lockfile across engines** — resolved via per-engine (non-frozen)
  install + java platform in the lock.
- **JVM native-access warning** — cosmetic; silenced via `--enable-native-access`.

## Out of scope

- Running the podman-based RSpec integration suite under JRuby.
- Changing the MRI runtime beyond adding `sequel`.

## Files

Create: `lib/gemvault/database.rb`, `spec/gemvault/database_spec.rb`.
Modify: `lib/gemvault/vault.rb`, `gemvault.gemspec`, `Gemfile`, `Gemfile.lock`,
`Rakefile`, `.github/workflows/ci.yml`.
Unchanged: `shim/*` (documented rationale).
