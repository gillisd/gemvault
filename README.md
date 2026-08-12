# Gemvault

A file that behaves like a private gem server.

You can commit it to your repo, drop it on S3, email it, put it on a USB drive, or whatever you feel like doing. Bundler and RubyGems read from it directly.

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
gemvault upgrade myvault.gemv                 # migrate to the current format
```

## Vault format versioning

Every vault records an on-disk **format version** — `1` for the original SQLite format, `2` for the current tarball format. This version lives inside the file and is **independent of the gemvault gem version**: it changes only when the storage layout changes, so upgrading the gem never invalidates your vaults.

gemvault reads any format up to the one it understands and **refuses a vault written by a newer gemvault** with a clear message (rather than silently misreading it).

The SQLite format (`1`) is **deprecated and read-only**: you can still read and migrate an existing SQLite vault, but `add`/`remove` are refused and print `gemvault upgrade`. Opening one shows a one-time deprecation notice (silence it with `GEMVAULT_SILENCE_DEPRECATIONS=1`). SQLite support will be removed in a future release (0.3–0.5). To migrate a vault to the current format:

```bash
gemvault upgrade myvault.gemv              # e.g. SQLite (v1) -> tarball (v2)
gemvault upgrade myvault.gemv --dry-run    # show the plan, change nothing
gemvault upgrade myvault.gemv --no-backup  # skip the default myvault.gemv.bak copy
```

`upgrade` preserves every gem and its timestamp, writes `myvault.gemv.bak` by default, and is a no-op on an already-current vault.

## How It Works

The gemv file is a tarball containing your .gem files and a json manifest. It has no dependencies other than the tar utilities that rubygems provides.

When Bundler sees `type: :vault` in your Gemfile, it auto-installs the `bundler-source-vault` plugin from rubygems.org. The plugin implements the `Bundler::Plugin::API::Source` interface — it reads gemspecs from the vault, participates in dependency resolution, then extracts and installs gems from the vault's blob storage.

The RubyGems plugin works similarly: `gem install --source vault.gemv` loads specs and extracts gems on demand.

## Recovering from broken bundler plugin state: `gemvault doctor`

Two kinds of wreckage make every `bundle install` fail, and `gemvault doctor` repairs both.

**A ghost installation.** If a gem home holds a `specifications/bundler-source-vault-<version>.gemspec` whose `gems/` directory is gone (an interrupted `gem uninstall`, a hand-cleaned gem home), bundler trusts the leftover record and every install dies with:

```
Installing bundler-source-vault 0.2.4
Failed to install plugin `bundler-source-vault`, due to Bundler::Plugin::MalformattedPlugin (plugins.rb was not found in the plugin.)
```

Deleting `.bundle` or the lockfile cannot help — the wreck lives in the machine's gem home, not the project. `doctor` finds such records across your gem roots, removes them (reporting each), and reinstalls the plugin.

**A broken plugin path.** If you installed `bundler-source-vault` from a local path (e.g. `plugin "bundler-source-vault", path: "/path/to/gemvault"` in a Gemfile), bundler records that absolute path in its plugin index. Moving, renaming, or deleting the source directory afterwards invalidates the stored path, and the next `bundle install` prints:

```
The following plugin paths don't exist: /path/to/gemvault/shim/.
Continuing without installing plugin bundler-source-vault.
```

Once the plugin skips loading, bundler crashes with `NoMethodError: undefined method 'new' for nil` on any Gemfile that uses `type: :vault`. This is a bundler limitation — the plugin index isn't revalidated against the filesystem, and there's no plugin-side hook that fires early enough to preempt it.

To recover, update the Gemfile to point at the new path and run:

```bash
gemvault doctor
```

`doctor` removes any ghost installation records, clears the broken entry from bundler's plugin index (`bundle plugin uninstall bundler-source-vault`) and then, when a Gemfile exists, re-runs `bundle install`, which reinstalls the plugin against whatever the current Gemfile declares. Run it from your project directory. If a ghost record sits in a root-owned gem home, doctor says so on one line — re-run it with permissions for that gem home (e.g. `sudo gemvault doctor`).

A project whose Gemfile is inline (`require "bundler/inline"`) works too. Such a script keeps its plugin index in `<project>/.bundle/plugin`, a root bundler only consults while the script runs; doctor reaches it the same way the script did. With no Gemfile on disk there is nothing to reinstall from, so doctor clears the entry, says so, and exits 0 — the inline gemfile reinstalls the plugin the next time the script runs. Run outside any project, doctor works against bundler's global index and points you back at the project directory for the reinstall.

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
