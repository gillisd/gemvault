# Gemvault

Multi-gem portable archives for Ruby. A single `.gemv` file contains multiple gems backed by SQLite. Commit it, send it over Slack, reference it in your Gemfile.

## Quick Start

### 1. Create a vault and add gems

```bash
gemvault new myvault                          # creates myvault.gemv
gemvault add myvault.gemv foo.gem bar.gem     # add .gem files
gemvault list myvault.gemv                    # list contents
```

### 2. Use it in your Gemfile

> **Important:** Until `bundler-source-vault` is published to rubygems.org, you
> must add the `plugin` line pointing at your local clone. Without it, Bundler
> will try to fetch the plugin from rubygems.org and fail.

```ruby
# Gemfile

source "https://rubygems.org"

# REQUIRED for local/unpublished plugin — tells Bundler where to find it.
# Remove this line once bundler-source-vault is published to rubygems.org.
plugin "bundler-source-vault", path: "/path/to/gemvault"

source "myvault.gemv", type: :vault do
  gem "foo"
  gem "bar"
end
```

Then:

```bash
bundle install
bundle exec ruby -e "require 'foo'; puts 'OK'"
```

### Why the `plugin` line is needed

When Bundler sees `type: :vault`, it auto-infers a plugin named `bundler-source-vault` and tries to install it from rubygems.org. Since the gem isn't published yet, that fails. The `plugin ... path:` directive tells Bundler to load the plugin from a local path instead, bypassing the remote lookup entirely.

Once published, the `plugin` line becomes unnecessary — Bundler's auto-install will just work.

## CLI Reference

| Command | Description |
|---------|-------------|
| `gemvault new NAME` | Create `NAME.gemv` with empty schema |
| `gemvault add VAULT GEM [GEM...]` | Add .gem files to vault |
| `gemvault list VAULT` | List gems in vault |
| `gemvault remove VAULT NAME [VERSION]` | Remove gem(s) from vault |
| `gemvault extract VAULT NAME [VERSION] [-o DIR]` | Extract .gem file(s) to disk |
| `gemvault version` | Print version |
| `gemvault help` | Print usage |

## How It Works

A `.gemv` file is a SQLite database containing gem metadata and raw `.gem` blobs. You can inspect it directly:

```bash
sqlite3 myvault.gemv "SELECT name, version, platform FROM gems"
```

The Bundler plugin (`bundler-source-vault`) implements the `Bundler::Plugin::API::Source` interface. When `bundle install` runs, it reads gemspecs from the vault, participates in dependency resolution, then extracts and installs individual gems from the vault's blob storage.

## Development

```bash
git clone <repo>
cd gemvault
bundle install
bundle exec rake test    # 77 tests
```

## License

MIT
