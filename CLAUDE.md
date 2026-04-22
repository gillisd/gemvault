# CLAUDE.md — Gemvault

## Rubocop

Do NOT modify `.rubocop.yml` or use inline `# rubocop:disable` tags without explicit permission. Fix the code to satisfy the cop instead.

## General rules

1. Specs always come first. Every plan should start with the skeleton of the BDD specs being added, changed or removed. Skeleton means the empty RSpec language, without implementation.
2. Specs should never have comments. Any urge to put a comment in a spec means that comment should probably be its own spec
3. DO NOT edit .rubocop.yml or add inline rubocop exemptions without explicit permission
4. DO NOT run any git command that will rewrite history without explicit permission
5. PREFER method & class extraction over comments
6. Making new files, classes, modules, and methods IS NOT overengineering
7. BEFORE writing code, identify which domain concept owns the behavior. Each class and module should have a single responsibility. If the new behavior doesn't fit an existing class's responsibility, create a new one — don't expand the scope of what's already there.
8. DO NOT name classes with suffixes like "-er" or "-or" unless using a canonical pattern name (e.g., Parser, Router, Controller)
9. ALWAYS write specs first. The workflow is: identify the domain concept (rule 5), write specs describing its behavior, then implement. No implementation without a failing spec.

## Additional rules

1. NEVER use Ruby's `sleep` method
2. NEVER create any class ending in "er" or "or"

## Project Overview

Multi-gem portable archives backed by SQLite. A single `.gemv` file contains multiple `.gem` files.

Two gems, one repo:

- **`gemvault`** — the real gem. All code, CLI, RubyGems plugin. Published to rubygems.org.
- **`bundler-source-vault`** — thin shim in `shim/`. Depends on `gemvault`, has a `plugins.rb` that registers the Bundler source. Published to rubygems.org so Bundler's `type: :vault` auto-discovery works. Users never interact with this name directly.

### User experience

```ruby
# Gemfile — once both gems are published to rubygems.org, no plugin line needed:
source "myvault.gemv", type: :vault do
  gem "foo"
end

# Until then, point Bundler at the local source:
plugin "bundler-source-vault", path: "/path/to/gemvault"
```

Bundler auto-infers `bundler-source-vault` → installs it → pulls in `gemvault` as dependency → `plugins.rb` registers the vault source.

Also works as a RubyGems plugin:

```bash
gem install --source myvault.gemv foo
gem install --source file:///path/to/myvault.gemv foo
```

## Architecture

- `gemvault.gemspec` — main gem spec (name: `gemvault`)
- `lib/gemvault/vault.rb` — Core vault class (SQLite CRUD for gem blobs + specs)
- `lib/gemvault/cli.rb` — CLI dispatcher (new/add/list/remove/extract)
- `lib/bundler/plugin/vault_source.rb` — Bundler `Plugin::API::Source` implementation
- `lib/rubygems_plugin.rb` — RubyGems plugin: monkey-patches for `--source myvault.gemv` support
- `lib/rubygems/source/vault.rb` — `Gem::Source::Vault` class (spec loading, download, `file://` URI handling, verbose logging)
- `lib/rubygems/resolver/vault_set.rb` — `Gem::Resolver::VaultSet` for dependency resolution
- `exe/gemvault` — CLI executable
- `shim/bundler-source-vault.gemspec` — thin shim gemspec depending on `gemvault`
- `shim/plugins.rb` — Bundler plugin registration + `Gem::Specification.dirs` workaround
- `plugins.rb` — development-only redirect to `shim/plugins.rb` (not shipped in gems)

## Key Design Decisions

- SQLite storage — random access, ACID, single file, inspectable with `sqlite3` CLI
- Specs extracted from gem blobs at runtime (no separate spec storage)
- Vault opened/closed per operation in the source plugin (no persistent connection)
- `fetch_gemspec_files` checks installed state — Bundler computes `full_gem_path` as `dirname(loaded_from)`, so `loaded_from` must point inside the gem directory
- `bundler-source-vault` name exists because Bundler auto-infers plugin name from `type: :vault` → `bundler-source-vault`
- `file://` URIs stripped to plain paths in `Gem::Source::Vault#initialize`
- Verbose logging via `Gem::UserInteraction#verbose` for `--verbose` support

## Testing

```bash
bundle exec rake test
```

- `test/vault_test.rb` — 33 unit tests for Vault class
- `test/vault_source_test.rb` — 17 unit tests for Bundler source plugin
- `test/integration_test.rb` — 12 end-to-end bundle install tests
- `test/cli_test.rb` — 32 CLI tests
- `test/rubygems_plugin_test.rb` — 28 tests (source, resolver, monkey-patches, gem install integration, file:// URI, verbose logging)

Integration tests use a manually-written Bundler plugin index to avoid rubygems.org resolution during testing.

## Dependencies

- `sqlite3` (~> 2.0) — runtime
- `bundler` (>= 2.0) — runtime
- `command_kit` (~> 0.6) — runtime (CLI)
- `minitest`, `rake` — development
