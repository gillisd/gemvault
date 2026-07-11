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

### Changed
- `sqlite3` is no longer a runtime dependency. Gemvault runs dependency-free on
  the tarball path (including JRuby); `sqlite3` is loaded lazily only to read a
  legacy SQLite vault, with a clear error if it is not installed.

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
