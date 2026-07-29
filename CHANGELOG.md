# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Tarball vault format ("Tarvault"): new vaults are portable tarballs with a
  `manifest.json` index and per-gem SHA256 integrity, with no sqlite3 dependency
  on the read/write path (works on JRuby). The original SQLite format
  ("Dbvault") is still read transparently.
- Vaults carry an explicit on-disk **format version**, decoupled from the gem
  version and validated on open; gemvault refuses a vault written by a newer
  gemvault instead of misreading it.
- `gemvault upgrade` migrates a vault to the current format (e.g. SQLite → tar),
  preserving every gem and timestamp, writing a `.bak` backup by default, with
  `--dry-run` and `--no-backup` flags. It is a no-op on an already-current vault.

- All CLI commands accept `vault://` and `file://` locators wherever they take
  a vault path, e.g. `gemvault list vault:///path/to/myvault.gemv`; resolution
  is shared with the RubyGems source via `Gemvault::VaultPath` (issue #9).

### Fixed
- `bundle plugin install bundler-source-vault` no longer dies with
  `LoadError: cannot load such file -- bundler/plugin/vault_source`. The shim's
  `plugins.rb` now derives the gem root from its own installed location (local
  plugin root, global plugin root, or plain GEM_HOME), registers any spec dirs
  RubyGems is not searching, and resets RubyGems' spec stub cache when it
  predates the just-installed gems (issue #10).
- `bundle exec` no longer fails Gemfile parsing with `Could not find 'bundler'
  (>= 2.0)` under `path: vendor` on rubies that ship bundler as a regular gem:
  gemvault no longer declares `bundler` as a runtime dependency (issue #12).
- Vault gems whose versions carry a non-numeric suffix (e.g. `0.2.1.patch1`)
  install from a vault with `gem install --pre`, matching RubyGems' prerelease
  semantics (issue #6).
- Repeated `bundle install` no longer fails with `cannot load such file --
  bundler/plugin/vault_source` on machines that have gemvault installed
  system-wide. Bundler skips installing a plugin dependency already present on
  the ambient GEM_PATH, so the plugin root holds only the shim; once the app
  bundle is populated Bundler restricts GEM_PATH to it and the ambient copy
  falls out of scope. The shim now locates gemvault's `lib` across every root
  that can hold it — `Gem.default_path` above all, which is what RubyGems knows
  about its own gem roots and therefore covers rubies from rbenv, asdf, chruby,
  Homebrew and distros, none of which export `GEM_HOME` or `GEM_PATH` — and
  loads it via `$LOAD_PATH` rather than gem activation (issue #13).
- The vault source registers correctly when Bundler evaluates the plugin more
  than once in a process; gemvault is resolved and required only on the first
  evaluation, so `Gemvault::GemEntry` can no longer be defined twice from two
  different gem roots (issue #13).
- `gemvault new` no longer raises `cannot load such file -- json` on a stock
  distro ruby. json backs the tarball vault's manifest, so every current-format
  vault needs it; it is a default gem upstream but a separate package on
  distros, where `dnf install ruby` leaves it absent. It is now a declared
  runtime dependency.
- Reading a vault through the Bundler source no longer raises `cannot load such
  file -- json` either. Loading gemvault off `$LOAD_PATH` skips activation, and
  therefore skips its dependencies, so the declared dependency alone did not
  reach the plugin path. The shim now resolves gemvault's declared runtime
  dependencies the same way it resolves gemvault and puts their require paths —
  extension directories included — on `$LOAD_PATH`. A dependency it cannot find
  is skipped rather than fatal, which is what activation could not do.
- `bundle install` no longer fails with `Could not find 'command_kit' (~> 0.6)`
  when gemvault is installed into the plugin root without its dependencies.
  Loading the vault source no longer activates the gemvault gem, which would
  demand the full runtime dependency set; `vault_source.rb` reaches the rest of
  gemvault through `require_relative` alone (issue #13).

### Changed
- `sqlite3` is no longer a runtime dependency. Gemvault runs dependency-free on
  the tarball path (including JRuby); `sqlite3` is loaded lazily only to read a
  legacy SQLite vault, with a clear error if it is not installed.
- `bundler` is no longer a runtime dependency; the Bundler plugin always runs
  inside an existing Bundler process, and the declared dependency broke gem
  activation in restricted GEM_PATH contexts.
- CI is unblocked (issue #11): RuboCop's TargetRubyVersion now matches the
  gemspec's `required_ruby_version` floor (3.4.8), the previously-missing
  `spec:integration` rake task exists alongside a non-integration `spec:core`, the
  unit job no longer needs podman, and the integration job installs podman
  when the runner image lacks it.
- Reading a vault's `manifest.json` is now strict: an entry missing any required
  field (`name`, `version`, `platform`, `created_at`, `sha256`, `encrypted`)
  raises instead of silently loading `nil` fields, so a truncated or hand-edited
  manifest fails fast rather than yielding a subtly broken vault.

### Deprecated
- The SQLite vault format is deprecated and now **read-only**: existing SQLite
  vaults can be read and migrated but no longer written (`add`/`remove` raise and
  point at `gemvault upgrade`). Opening one prints a one-time deprecation notice
  (silenceable with `GEMVAULT_SILENCE_DEPRECATIONS=1`). SQLite support will be
  removed in a future release (0.3-0.5); migrate with `gemvault upgrade`.

## [0.1.3] - 2026-06-22

### Added
- `gemvault doctor` command to recover from a broken `bundler-source-vault`
  plugin index entry after its path-installed source directory has been renamed
  (issue #1).

### Fixed
- `gem install --source vault://<absolute-path>` no longer resolves the vault
  relative to the working directory; the `vault://` scheme is now stripped just
  like `file://` (issue #5).
- `bundle install` logs now show the vault path as written in the Gemfile
  (e.g. `vendor/vendored.gemv`) instead of only the basename (issue #3).
- Renaming a `.gemv` file and updating the Gemfile to match no longer crashes
  `bundle install` on the stale lockfile entry; the vault existence check is
  deferred until the source is actually queried (issue #2).

### Changed
- CI runs the unit and container-backed integration suites as separate jobs, and
  the codebase is RuboCop-clean.

[0.1.3]: https://github.com/gillisd/gemvault/releases/tag/v0.1.3
