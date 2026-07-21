# Test fixtures

## `legacy-v1.gemv`

A **format-1 (SQLite / "Dbvault")** vault, committed as a binary test asset. It
represents the deprecated legacy format that `gemvault upgrade` migrates from.
The gemvault codebase can no longer *write* SQLite vaults (`Dbvault` is a
read-only reader), so this fixture is checked in rather than built at test time.

Contents:

- `foo-1.0.0` and `bar-2.0.0`, each with `created_at = 2000-01-01 00:00:00`
  (a fixed value so the upgrade timestamp-preservation test can assert it).

### Regenerating

The on-disk SQLite schema is identical across gemvault 0.1.x and the version that
introduced Tarvault, so any gemvault with SQLite write support produces an
equivalent file. Regenerate from a SQLite-era gemvault (e.g. a git revision
before Dbvault became read-only, or `gem install gemvault -v 0.1.4`):

```ruby
require "gemvault/dbvault"          # a build with SQLite write support
require "gem_factory"                # test/support/gem_factory.rb
dir = Pathname(Dir.mktmpdir)
foo = GemFactory.new("foo", "1.0.0", dir: dir).build
bar = GemFactory.new("bar", "2.0.0", dir: dir).build
Gemvault::Dbvault.open("spec/fixtures/legacy-v1.gemv", create: true) do |v|
  v.add(foo.to_s, created_at: "2000-01-01 00:00:00")
  v.add(bar.to_s, created_at: "2000-01-01 00:00:00")
end
```

Both this fixture and the tests that use it are removed when SQLite support is
dropped (0.3–0.5).
