# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2026-06-22

### Added
- `gemvault plugin-heal` command to recover from a broken `bundler-source-vault`
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
