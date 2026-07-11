# JRuby Support (Sequel) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `gemvault` install and run on JRuby by replacing the `sqlite3` C-extension gem with `sequel` (which uses `sqlite3` on MRI and the pure-Java `jdbc-sqlite3` driver on JRuby), and ship/test both platform variants.

**Architecture:** All SQLite access is isolated in `lib/gemvault/vault.rb`. Introduce a tiny `Gemvault::Database.connect(path)` seam that returns a `Sequel::Database` chosen by `RUBY_ENGINE`. `Vault` uses Sequel's dataset API; external behavior is unchanged and the existing `test/vault_test.rb` is the cross-engine regression net. Driver dependency is conditional in the gemspec; a `-java` platform gem is buildable under JRuby.

**Tech Stack:** Ruby 4.0.1 (MRI) + JRuby 10.1.0.0 (Ruby 4.0.0 compat, OpenJDK 25), `sequel ~> 5.0`, `sqlite3 ~> 2.0` (MRI), `jdbc-sqlite3 ~> 3.46` (JRuby), RSpec + Minitest, RuboCop (rubocop-claude/rspec/performance/rake).

---

## Context

Running `bundle install` on JRuby fails: the gemspec depends on `sqlite3 ~> 2.0`, a C extension that cannot build on the JVM. The fix (Approach A, chosen with the user) routes all DB access through **Sequel**, the idiomatic cross-engine SQL toolkit — its only runtime dep is `bigdecimal` (a default gem), and a live spike on JRuby 10.1.0.0 proved byte-perfect BLOB round-trips, `String` `created_at`, and correct delete/count semantics via `jdbc-sqlite3`. Scope is **full multi-platform minus automated publishing**: conditional deps, a `-java` gem buildable under JRuby, a JRuby CI *test* job, and a documented two-engine release recipe (no blind rubygems push workflow — the gemspec requires MFA).

Design doc: `docs/superpowers/specs/2026-07-11-jruby-support-design.md`.

## Environment (already done — do NOT redo)

- Branch `jruby-support` is checked out.
- JRuby installed at `/home/dev/.rbenv/versions/jruby-10.1.0.0` (Java 25 at `/usr/lib/jvm/java-25-openjdk`).
- Spike validated Sequel + jdbc-sqlite3 on this JRuby.

**Run MRI commands** normally (`bundle exec ...`). **Run JRuby commands** with this prelude (prepending JRuby's bin so `ruby`/`gem`/`bundle`/`jruby` all resolve to JRuby and bundler's re-exec finds `jruby`):

```bash
export PATH="/home/dev/.rbenv/versions/jruby-10.1.0.0/bin:$PATH"
export JAVA_HOME="/usr/lib/jvm/java-25-openjdk"
export JAVA_OPTS="--enable-native-access=ALL-UNNAMED"   # silence Java 25 JDBC native-access warning
export BUNDLE_FROZEN=false                                # JRuby re-resolves jdbc-sqlite3 non-frozen
```

## RuboCop rules that constrain this work

- No `# frozen_string_literal` comment (forbidden). Double-quoted strings. Trailing commas in multiline literals/args.
- Modules/classes need an rdoc comment (`Style/Documentation`); specs/tests are exempt.
- `rubocop-claude` applies stricter-than-stock metrics — keep methods/classes small. If a `Metrics/*` cop fires, **fix by extraction, never disable** (`.rubocop.yml` and inline disables are off-limits per CLAUDE.md).
- Layout offenses are auto-correctable: after edits run `bundle exec rubocop -a <files>` then re-check.
- `RSpec/MultipleExpectations` (stock Max 1) → one `expect` per example. `RSpec/MultipleMemoizedHelpers` Max 10.

---

## Task 1: Commit design doc and this plan

**Files:**
- Commit: `docs/superpowers/specs/2026-07-11-jruby-support-design.md` (already written)
- Create: `docs/superpowers/plans/2026-07-11-jruby-support.md` (copy of this plan)

- [ ] **Step 1: Save this plan into the repo**

Copy this plan file to `docs/superpowers/plans/2026-07-11-jruby-support.md`.

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-07-11-jruby-support-design.md docs/superpowers/plans/2026-07-11-jruby-support.md
git commit -m "docs: JRuby support design + implementation plan"
```

---

## Task 2: `Gemvault::Database` engine seam (TDD)

**Files:**
- Test: `spec/gemvault/database_spec.rb` (create)
- Create: `lib/gemvault/database.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/gemvault/database_spec.rb`:

```ruby
RSpec.describe Gemvault::Database do
  let(:tmpdir) { Dir.mktmpdir("gemvault_db") }
  let(:path) { File.join(tmpdir, "test.db") }
  subject(:db) { described_class.connect(path) }

  after do
    db.disconnect
    FileUtils.rm_rf(tmpdir)
  end

  describe ".connect" do
    it "creates and queries a table" do
      db.run("CREATE TABLE items (name TEXT NOT NULL)")
      db[:items].insert(name: "foo")
      expect(db[:items].count).to eq(1)
    end

    it "round-trips binary blob data byte-for-byte" do
      db.run("CREATE TABLE blobs (data BLOB NOT NULL)")
      bytes = (0..255).map(&:chr).join.b
      db[:blobs].insert(data: Sequel.blob(bytes))
      expect(db[:blobs].select(:data).first[:data]).to eq(bytes)
    end

    it "returns the affected-row count from a delete" do
      db.run("CREATE TABLE items (name TEXT NOT NULL)")
      2.times { db[:items].insert(name: "foo") }
      expect(db[:items].where(name: "foo").delete).to eq(2)
    end

    it "reads a datetime('now') default column as a String" do
      db.run("CREATE TABLE stamped (at TEXT NOT NULL DEFAULT (datetime('now')))")
      db[:stamped].insert
      expect(db[:stamped].select(:at).first[:at]).to be_a(String)
    end
  end
end
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `bundle exec rspec spec/gemvault/database_spec.rb`
Expected: FAIL — `uninitialized constant Gemvault::Database` (or NameError).

- [ ] **Step 3: Implement the seam**

Create `lib/gemvault/database.rb`:

```ruby
require "sequel"

module Gemvault
  # Connects to a vault's SQLite database with the driver appropriate for the
  # running engine: the sqlite3 C extension on MRI, the jdbc-sqlite3 JDBC
  # driver on JRuby. Both are presented as a single Sequel::Database.
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

- [ ] **Step 4: Require it from the library**

In `lib/gemvault.rb`, add after `require_relative "gemvault/version"` (line 1):

```ruby
require_relative "gemvault/database"
```

- [ ] **Step 5: Run the spec — confirm it passes**

Run: `bundle exec rspec spec/gemvault/database_spec.rb`
Expected: PASS (4 examples, 0 failures).

- [ ] **Step 6: RuboCop the new files**

Run: `bundle exec rubocop lib/gemvault/database.rb spec/gemvault/database_spec.rb`
Expected: no offenses. If any Layout offense: `bundle exec rubocop -a lib/gemvault/database.rb spec/gemvault/database_spec.rb` then re-run.

- [ ] **Step 7: Commit**

```bash
git add lib/gemvault/database.rb lib/gemvault.rb spec/gemvault/database_spec.rb
git commit -m "feat: add Gemvault::Database engine-aware Sequel connection seam"
```

---

## Task 3: Refactor `Vault` onto Sequel (regression-guarded by `test/vault_test.rb`)

**Files:**
- Modify: `lib/gemvault/vault.rb` (full rewrite below)
- Safety net: `test/vault_test.rb` (unchanged — must stay green on MRI)

- [ ] **Step 1: Confirm the safety net is green before touching code**

Run: `bundle exec rake test`
Expected: PASS — `... 0 failures, 0 errors, 0 skips`.

- [ ] **Step 2: Replace `lib/gemvault/vault.rb` with the Sequel version**

Full new file contents:

```ruby
require_relative "database"
require "rubygems/package"
require "fileutils"
require "tempfile"
require_relative "gem_entry"
require_relative "gem_reference"

module Gemvault
  # SQLite-backed archive of .gem blobs; supports add/remove/list/extract.
  class Vault
    class Error < StandardError; end
    class NotFoundError < Error; end
    class DuplicateGemError < Error; end
    class InvalidGemError < Error; end

    SCHEMA_VERSION = "1".freeze
    SQLITE_MAGIC = "SQLite format 3#{0.chr}".freeze

    CREATE_METADATA_TABLE_SQL = <<~SQL.freeze
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    SQL

    CREATE_GEMS_TABLE_SQL = <<~SQL.freeze
      CREATE TABLE gems (
        name TEXT NOT NULL,
        version TEXT NOT NULL,
        platform TEXT NOT NULL DEFAULT 'ruby',
        data BLOB NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        PRIMARY KEY (name, version, platform)
      )
    SQL

    attr_reader :path

    def self.open(path, **opts, &block)
      raise ArgumentError, "#{name}.open requires a block" unless block

      vault = new(path, **opts)
      begin
        yield vault
      ensure
        vault.close
      end
    end

    def initialize(path, create: false)
      @path = File.expand_path(path)
      create ? create_vault! : open_vault!
    end

    def add(gem_path)
      gem_path = File.expand_path(gem_path)
      raise NotFoundError, "Gem file not found: #{gem_path}" unless File.file?(gem_path)

      spec = load_gem_spec(gem_path)
      raise_if_duplicate(spec)
      insert_gem(gem_path, spec)
    end

    def remove(reference)
      case reference
      in GemReference::AnyVersion[name:]
        db[:gems].where(name: name).delete
      in GemReference::SpecificVersion[name:, version:]
        db[:gems].where(name: name, version: version.to_s).delete
      end
    end

    def gem_data(name, version, platform: "ruby")
      row = db[:gems].where(name: name, version: version, platform: platform).select(:data).first
      raise NotFoundError, "Gem not found: #{name}-#{version} (#{platform})" unless row

      row[:data]
    end

    def specs
      gem_entries.map { |entry| spec_from_blob(entry.name, entry.version, entry.platform) }
    end

    def gem_entries
      db[:gems]
        .select(:name, :version, :platform, :created_at)
        .order(:name, :version)
        .map { |row| GemEntry.new(**row) }
    end

    def size
      db[:gems].count
    end

    def close
      return unless @db

      @db.disconnect
      @db = nil
    end

    def with_gem_file(name, version, platform: "ruby")
      data = gem_data(name, version, platform: platform)
      tmpfile = write_tempfile(data)
      begin
        yield tmpfile.path
      ensure
        tmpfile.close unless tmpfile.closed?
        tmpfile.unlink
      end
    end

    def spec_from_blob(name, version, platform = "ruby")
      with_gem_file(name, version, platform: platform) do |path|
        Gem::Package.new(path).spec
      end
    end

    private

    def db
      @db || raise(ArgumentError, "vault is closed")
    end

    def create_vault!
      raise Error, "Vault already exists: #{@path}" if File.exist?(@path)

      @db = Gemvault::Database.connect(@path)
      create_schema
    end

    def open_vault!
      raise NotFoundError, "Vault not found: #{@path}" unless File.exist?(@path)

      validate_sqlite!
      @db = Gemvault::Database.connect(@path)
    end

    def load_gem_spec(gem_path)
      Gem::Package.new(gem_path).spec
    rescue StandardError => e
      raise InvalidGemError, "Invalid gem file #{gem_path}: #{e.message}"
    end

    def raise_if_duplicate(spec)
      existing = db[:gems].where(
        name: spec.name,
        version: spec.version.to_s,
        platform: spec.platform.to_s,
      )
      return if existing.empty?

      raise DuplicateGemError,
            "Gem already in vault: #{spec.name}-#{spec.version} (#{spec.platform})"
    end

    def insert_gem(gem_path, spec)
      db[:gems].insert(
        name: spec.name,
        version: spec.version.to_s,
        platform: spec.platform.to_s,
        data: Sequel.blob(File.binread(gem_path)),
      )
    end

    def write_tempfile(data)
      tmpfile = Tempfile.new(["vault_gem", ".gem"])
      tmpfile.binmode
      tmpfile.write(data)
      tmpfile.close
      tmpfile
    end

    def create_schema
      db.run(CREATE_METADATA_TABLE_SQL)
      db.run(CREATE_GEMS_TABLE_SQL)
      insert_metadata("vault_version", SCHEMA_VERSION)
      insert_metadata("created_at", Time.now.utc.strftime("%Y-%m-%d %H:%M:%S"))
    end

    def insert_metadata(key, value)
      db[:metadata].insert(key: key, value: value)
    end

    def validate_sqlite!
      return if File.binread(@path, SQLITE_MAGIC.bytesize) == SQLITE_MAGIC

      raise Error, "Not a valid vault file (not SQLite): #{@path}"
    end
  end
end
```

Key behavior notes (verified against Sequel 5.106.0 source):
- Symbol-keyed rows → `GemEntry.new(**row)` directly (drop `transform_keys`).
- `Dataset#delete`/`#count`/`#empty?` return Integer/Integer/Boolean on both adapters.
- Two separate `db.run` DDL calls (JDBC can't run a multi-statement string).
- `Sequel.blob(...)` binds/reads BLOBs byte-exact; `created_at` (TEXT) stays a String.
- Sequel auto-reconnects after `disconnect`, so the guarded private `db` accessor raising `ArgumentError` preserves the post-close contract; `close` guards on `@db` for idempotency.

- [ ] **Step 3: Run the full unit suite — confirm still green**

Run: `bundle exec rake test`
Expected: PASS — `0 failures, 0 errors`. In particular `test_gem_data_returns_matching_bytes` (blob bytes), `test_open_yields_vault_and_closes` / `test_open_closes_on_raise` (post-close `ArgumentError`), `test_close_is_idempotent`, and `assert_alpha_entry` (`created_at` non-nil String) must pass.

- [ ] **Step 4: RuboCop**

Run: `bundle exec rubocop lib/gemvault/vault.rb`
Expected: no offenses. Run `bundle exec rubocop -a lib/gemvault/vault.rb` for any Layout (dot-alignment) fixes, then re-run.
If a `Metrics/ClassLength` (or `MethodLength`) offense appears, extract the two DDL constants + a `create(db)` helper into a new file `lib/gemvault/vault/schema.rb` as `module Gemvault; class Vault; module Schema ... end; end; end`, `require_relative "vault/schema"`, and call `Schema.create(db)` from `create_schema`. Do NOT disable the cop.

- [ ] **Step 5: Commit**

```bash
git add lib/gemvault/vault.rb
git commit -m "refactor: back Vault with Sequel instead of the sqlite3 gem directly"
```

---

## Task 4: Conditional gemspec deps + `-java` platform, regenerate MRI lock

**Files:**
- Modify: `gemvault.gemspec:34`
- Modify: `Gemfile.lock` (regenerated)

- [ ] **Step 1: Edit `gemvault.gemspec`**

Replace line 34 (`spec.add_dependency "sqlite3", "~> 2.0"`) with:

```ruby
  spec.add_dependency "sequel", "~> 5.0"

  if RUBY_ENGINE == "jruby"
    spec.platform = "java"
    spec.add_dependency "jdbc-sqlite3", "~> 3.46"
  else
    spec.add_dependency "sqlite3", "~> 2.0"
  end
```

Leave the `bundler` and `command_kit` dependencies (lines 32-33) unchanged. (`gemvault.gemspec` is excluded from `Metrics/BlockLength`, so the conditional is fine.)

- [ ] **Step 2: Regenerate the MRI lockfile**

Run: `bundle install`
Expected: resolves and adds `sequel`; `sqlite3` stays (MRI). Confirm:

Run: `git diff Gemfile.lock | grep -E "^\+.*(sequel|sqlite3|jdbc)"`
Expected: a `+  sequel (5.x)` line added; no `java` platform line; no `jdbc-sqlite3`.

- [ ] **Step 3: Verify MRI suite + rubocop still green**

Run: `bundle exec rake test && bundle exec rubocop`
Expected: tests PASS; rubocop no offenses.

- [ ] **Step 4: Commit**

```bash
git add gemvault.gemspec Gemfile.lock
git commit -m "feat: conditional sqlite driver + sequel dep; build -java gem on JRuby"
```

---

## Task 5: Prove the fix on JRuby (the original bug + cross-engine contract)

**Files:** none changed (verification). This reproduces the reported failure being fixed.

- [ ] **Step 1: `bundle install` on JRuby now succeeds**

```bash
export PATH="/home/dev/.rbenv/versions/jruby-10.1.0.0/bin:$PATH"
export JAVA_HOME="/usr/lib/jvm/java-25-openjdk"
export JAVA_OPTS="--enable-native-access=ALL-UNNAMED"
export BUNDLE_FROZEN=false
bundle install
```
Expected: SUCCESS — resolves `jdbc-sqlite3` + `sequel`, no `sqlite3` C-extension build. (Before this work it failed compiling the C extension.)

- [ ] **Step 2: Run the unit suite on JRuby**

Run (same shell): `bundle exec rake test`
Expected: the Vault/database contract passes on JRuby — byte-perfect blobs via JDBC, `created_at` String, delete/count integers, post-close `ArgumentError`. Triage any incidental non-DB failure in other suites (e.g. a JRuby-specific `Process`/`fork` quirk in cli/plugin tests) as a separate item; the `vault_test.rb` suite is the core cross-engine proof and must be green.

- [ ] **Step 3: Restore the committed MRI lockfile**

JRuby's `bundle install` rewrites `Gemfile.lock` for the java platform; the committed lock stays MRI-resolved (JRuby re-resolves per-engine at install time).

```bash
git checkout -- Gemfile.lock
git status --short   # expect: clean
```

---

## Task 6: JRuby CI job + release recipe

**Files:**
- Modify: `.github/workflows/ci.yml` (add a `jruby` job)
- Create: `RELEASING.md`

- [ ] **Step 1: Add the JRuby test job**

Append this job under `jobs:` in `.github/workflows/ci.yml` (keep `unit` and `integration` MRI-only):

```yaml
  jruby:
    runs-on: ubuntu-latest
    env:
      JAVA_OPTS: "--enable-native-access=ALL-UNNAMED"
      BUNDLE_FROZEN: "false"
    steps:
    - uses: actions/checkout@v4
    - name: Set up Java
      uses: actions/setup-java@v4
      with:
        distribution: temurin
        java-version: '21'
    - name: Set up JRuby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: jruby-10.1.0.0
        bundler-cache: true
    - name: Run unit tests
      run: bundle exec rake test
```

- [ ] **Step 2: Write `RELEASING.md`**

```markdown
# Releasing gemvault

gemvault ships two platform variants of each version:

- `gemvault-X.Y.Z.gem`       — C Ruby, depends on `sqlite3`
- `gemvault-X.Y.Z-java.gem`  — JRuby, depends on `jdbc-sqlite3`

The `-java` gem can only be built under JRuby: the gemspec sets
`spec.platform = "java"` and depends on `jdbc-sqlite3` only when
`RUBY_ENGINE == "jruby"`. `sequel` is a dependency of both variants.

The gem requires MFA (`rubygems_mfa_required`), so pushes are done manually
with an OTP (or via rubygems trusted publishing if configured later).

## Steps

1. Bump `Gemvault::VERSION`, update `CHANGELOG.md`.
2. Build + push the C-Ruby gem (under MRI):
   ```bash
   bundle exec rake build           # => pkg/gemvault-X.Y.Z.gem
   gem push pkg/gemvault-X.Y.Z.gem
   ```
3. Build + push the JRuby gem (under JRuby):
   ```bash
   export PATH="$(rbenv root)/versions/jruby-10.1.0.0/bin:$PATH"
   export JAVA_HOME=/usr/lib/jvm/java-25-openjdk
   bundle exec rake build           # => pkg/gemvault-X.Y.Z-java.gem
   gem push pkg/gemvault-X.Y.Z-java.gem
   ```
4. Push the shim (unchanged, platform-agnostic):
   ```bash
   bundle exec rake shim:release
   ```
5. Tag and push: `git tag vX.Y.Z && git push --tags`.
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml RELEASING.md
git commit -m "ci: add JRuby test job; document two-variant release"
```

---

## Task 7: Final cross-engine verification

**Files:** none changed.

- [ ] **Step 1: MRI gate**

Run: `bundle exec rake test && bundle exec rubocop`
Expected: tests PASS, rubocop clean. (`bundle exec rake spec` also runs the podman integration suite if podman is available; those specs use only the public Vault API and are unaffected — run if the container tooling is present.)

- [ ] **Step 2: JRuby gate**

```bash
export PATH="/home/dev/.rbenv/versions/jruby-10.1.0.0/bin:$PATH"
export JAVA_HOME="/usr/lib/jvm/java-25-openjdk"
export JAVA_OPTS="--enable-native-access=ALL-UNNAMED"
export BUNDLE_FROZEN=false
bundle install && bundle exec rake test
git checkout -- Gemfile.lock
```
Expected: `bundle install` succeeds; `vault_test` suite green.

- [ ] **Step 3: Verify both gem variants build**

MRI:
```bash
bundle exec rake build && ls pkg/gemvault-*.gem
```
Expected: `pkg/gemvault-X.Y.Z.gem` (no `-java`). Confirm its dep:
`gem specification pkg/gemvault-*.gem dependencies | grep -E "sqlite3|sequel"` → `sqlite3` + `sequel`.

JRuby:
```bash
export PATH="/home/dev/.rbenv/versions/jruby-10.1.0.0/bin:$PATH"
export JAVA_HOME="/usr/lib/jvm/java-25-openjdk"
bundle exec rake build && ls pkg/gemvault-*-java.gem
```
Expected: `pkg/gemvault-X.Y.Z-java.gem`. Confirm its dep:
`gem specification pkg/gemvault-X.Y.Z-java.gem dependencies | grep -E "jdbc-sqlite3|sequel"` → `jdbc-sqlite3` + `sequel`.

- [ ] **Step 4: Clean up build artifacts and finish**

```bash
git checkout -- Gemfile.lock 2>/dev/null || true
git status --short
```
Then follow superpowers:finishing-a-development-branch (open a PR to `master`).

---

## Verification summary

| Check | Command | Expected |
| --- | --- | --- |
| Original bug fixed | (JRuby) `bundle install` | succeeds, no C-ext build |
| MRI behavior preserved | `bundle exec rake test` | 0 failures |
| JRuby behavior | (JRuby) `bundle exec rake test` | vault suite green |
| New seam | `bundle exec rspec spec/gemvault/database_spec.rb` | 4 pass |
| Style | `bundle exec rubocop` | 0 offenses |
| MRI gem | (MRI) `rake build` | `gemvault-X.Y.Z.gem` w/ sqlite3+sequel |
| JRuby gem | (JRuby) `rake build` | `gemvault-X.Y.Z-java.gem` w/ jdbc-sqlite3+sequel |

## Critical files

- `lib/gemvault/vault.rb` — only file doing DB I/O; full Sequel rewrite + guarded `db` accessor.
- `lib/gemvault/database.rb` (new) — engine-aware `Sequel` connection seam.
- `lib/gemvault/gem_entry.rb` — unchanged; now fed native symbol-keyed rows.
- `gemvault.gemspec` — conditional driver dep + `sequel` + `spec.platform = "java"` on JRuby.
- `Gemfile.lock` — committed copy stays MRI-resolved; JRuby re-resolves at install.
- `test/vault_test.rb` — unchanged; the engine-agnostic regression net gating every step.
- `.github/workflows/ci.yml` — new `jruby` job.

## Risks & notes

- **rubocop-claude stricter metrics**: if `Metrics/ClassLength`/`MethodLength` fires on `Vault`, extract the DDL into `lib/gemvault/vault/schema.rb` (concrete fallback in Task 3 Step 4). Never disable cops or edit `.rubocop.yml`.
- **Dual-engine lockfile**: do NOT `bundle lock --add-platform java` under MRI (the MRI-eval'd gemspec would try to resolve `sqlite3` for java). Commit the MRI lock; JRuby resolves non-frozen. CI JRuby job sets `BUNDLE_FROZEN=false`.
- **`rake spec`** builds a podman MRI container (`Dockerfile.test`); it is orthogonal to the engine and MRI-only. Not required to verify this change.
- **Incidental JRuby test failures** in non-DB suites (cli/plugin) would be pre-existing engine quirks, not caused by this migration; triage separately.
- **shim gem** needs no change (pure Ruby; depends on `gemvault`, which resolves to the right platform variant).
