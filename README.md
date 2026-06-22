# Gemvault

A gem server in a file. No HTTP. No infrastructure.

A `.gemv` file is a SQLite database that contains Ruby gems. Commit it to your repo, drop it on S3, email it, put it on a USB drive — Bundler and RubyGems read from it directly. Private gems without running a server.

## Installation

```bash
gem install gemvault
```

## Usage

### Bundler

```ruby
# Gemfile
source "https://rubygems.org"

source "vendor/private.gemv", type: :vault do
  gem "my_private_gem"
end
```

```bash
bundle install
```

Bundler auto-discovers the `bundler-source-vault` plugin, installs it, and resolves gems from the vault alongside rubygems.org. No extra configuration.

### RubyGems CLI

```bash
gem install --source myvault.gemv my_private_gem
gem install --source file:///path/to/myvault.gemv my_private_gem
```

### Creating and managing vaults

```bash
gemvault new myvault                          # creates myvault.gemv
gemvault add myvault.gemv foo.gem bar.gem     # add .gem files
gemvault list myvault.gemv                    # list contents
gemvault remove myvault.gemv foo 1.0.0        # remove a gem
gemvault extract myvault.gemv foo -o vendor/  # extract .gem file to disk
```

## How It Works

A `.gemv` file is a SQLite database containing gem metadata and raw `.gem` blobs. You can inspect it directly:

```bash
sqlite3 myvault.gemv "SELECT name, version, platform FROM gems"
```

When Bundler sees `type: :vault` in your Gemfile, it auto-installs the `bundler-source-vault` plugin from rubygems.org. The plugin implements the `Bundler::Plugin::API::Source` interface — it reads gemspecs from the vault, participates in dependency resolution, then extracts and installs gems from the vault's blob storage.

The RubyGems plugin works similarly: `gem install --source vault.gemv` loads specs and extracts gems on demand.

## Recovering from a broken bundler plugin path: `gemvault plugin-heal`

If you installed `bundler-source-vault` from a local path (e.g. `plugin "bundler-source-vault", path: "/path/to/gemvault"` in a Gemfile), bundler records that absolute path in its plugin index. Moving, renaming, or deleting the source directory afterwards invalidates the stored path, and the next `bundle install` prints:

```
The following plugin paths don't exist: /path/to/gemvault/shim/.
Continuing without installing plugin bundler-source-vault.
```

Once the plugin skips loading, bundler crashes with `NoMethodError: undefined method 'new' for nil` on any Gemfile that uses `type: :vault`. This is a bundler limitation — the plugin index isn't revalidated against the filesystem, and there's no plugin-side hook that fires early enough to preempt it.

To recover, update the Gemfile to point at the new path and run:

```bash
gemvault plugin-heal
```

`plugin-heal` clears the broken entry from bundler's plugin index (`bundle plugin uninstall bundler-source-vault`) and then re-runs `bundle install`, which reinstalls the plugin against whatever the current Gemfile declares. Run it from your project directory.

The published `bundler-source-vault` gem installed from rubygems.org is immune to this: it lives in a bundler-managed directory that does not move.

## Development

```bash
git clone https://github.com/gillisd/gemvault
cd gemvault
bin/setup
bundle exec rake test         # unit tests
bundle exec rake spec         # specs + container integration tests
bundle exec rake              # all of the above + rubocop
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
