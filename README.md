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

## Stopping Bundler's plugin-reinstall noise: `gemvault patch-bundler`

Every `bundle install` reprints:

```
Installing command_kit 0.6.0
Installing sqlite3 2.9.3 (aarch64-linux-gnu)
Installing gemvault 0.1.2
Installing bundler-source-vault 0.1.2
```

even when nothing has changed. This is a Bundler bug, tracked upstream: [rubygems/rubygems#6630](https://github.com/rubygems/rubygems/issues/6630), with a structural fix proposed in [rubygems/rubygems#6957](https://github.com/rubygems/rubygems/pull/6957). `Bundler::Plugin.gemfile_install` calls `Installer.new.install_definition(definition)` with the declared plugins every time without checking whether any of them are already registered in the plugin index — so `install_from_specs` reinstalls them on every run. It affects every bundler plugin that declares runtime dependencies, not just this one.

Until the upstream PR lands in a Bundler release, gemvault ships a CLI that applies the minimal fix directly to Bundler's installed `plugin.rb`:

```bash
gemvault patch-bundler      # one-time, per bundler version on disk
```

The patch inserts one early return — `return if definition.dependencies.map(&:name).all? { |n| index.installed?(n) }` — right before `install_definition` runs. When the declared plugins are already registered, `gemfile_install` returns before it can reinstall anything. Plain `bundle install`, `bundle update`, and every other bundler subcommand then run exactly as they always do, minus the four bogus "Installing" lines.

The command scans system gem paths, Ruby stdlib (for bundled-default bundler), and any `vendor/ruby/*/gems/bundler-*/` in the current directory, and patches each `plugin.rb` it finds with a marker comment so `gemvault patch-bundler` is idempotent and `gemvault unpatch-bundler` reverses it cleanly. Newly-installed bundler versions need the command re-run once.

**Why patch Bundler in place and not monkey-patch from the plugin?** The bug fires in `Bundler::CLI::Install#run` before any plugin code loads (our `plugins.rb` only loads during `Bundler.definition`, which happens *after* the buggy `Plugin.gemfile_install` call). There is no earlier hook a third-party plugin can take, so nothing short of editing Bundler's own file gives a plain `bundle install` the fix.

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
