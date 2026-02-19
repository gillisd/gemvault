# CLAUDE.md — Gemvault

## IMPORTANT: Plugin Line Required in Gemfile

Until `bundler-source-vault` is published to rubygems.org, every Gemfile that uses a vault source **must** include the `plugin` directive pointing at the local clone:

```ruby
# REQUIRED — without this, `bundle install` fails with:
#   Could not find gem 'bundler-source-vault' in rubygems repository
plugin "bundler-source-vault", path: "/path/to/gemvault"

source "myvault.gemv", type: :vault do
  gem "foo"
end
```

**Why:** Bundler sees `type: :vault`, auto-infers a plugin named `bundler-source-vault`, and tries to install it from rubygems.org. Since it's not published, that fails. The `plugin ... path:` line tells Bundler to load it from disk instead.

**When to remove:** Once the gem is published to rubygems.org, the `plugin` line is no longer needed — Bundler's auto-install will handle it.

## Project Overview

Multi-gem portable archives backed by SQLite. A single `.gemv` file contains multiple `.gem` files. Implemented as a Bundler source plugin (`bundler-source-vault`).

## Architecture

- `lib/gemvault/vault.rb` — Core vault class (SQLite CRUD for gem blobs + specs)
- `lib/bundler/plugin/vault_source.rb` — Bundler `Plugin::API::Source` implementation
- `plugins.rb` — Plugin registration entry point
- `lib/gemvault/cli.rb` — CLI dispatcher (new/add/list/remove/extract)
- `exe/gemvault` — CLI executable

## Key Design Decisions

- SQLite storage — random access, ACID, single file, inspectable with `sqlite3` CLI
- Specs stored as `spec.to_ruby` text — avoids re-extracting from blob
- Vault opened/closed per operation in the source plugin (no persistent connection)
- `fetch_gemspec_files` checks installed state (same `full_gem_path` gotcha as bundler-source-package)

## Testing

```bash
bundle exec rake test    # 77 tests, 188 assertions
```

- `test/vault_test.rb` — 27 unit tests for Vault class
- `test/vault_source_test.rb` — 15 unit tests for Bundler source plugin
- `test/integration_test.rb` — 8 end-to-end bundle install tests
- `test/cli_test.rb` — 27 CLI tests

## Dependencies

- `sqlite3` (~> 2.0) — runtime
- `bundler` (>= 2.0) — runtime
- `minitest`, `rake` — development
