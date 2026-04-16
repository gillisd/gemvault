# Container Integration Tests — Remaining Work

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate all subprocess-based integration tests from `test/integration_test.rb` and `test/rubygems_plugin_test.rb` into Podman container tests, then remove the old tests.

**Architecture:** Each container test is a self-contained minitest file in `test/containers/` that runs inside a disposable `podman run --rm` container. The project is mounted read-only at `/gem`. A cached Docker image (`gemvault-test:latest`) has gemvault pre-installed; tests detect this and skip the build/install step. The host-side `rake test:containers` task orchestrates execution.

**Tech Stack:** Podman, minitest (stdlib), Docker image `ruby:4.0.1-slim`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `test/containers/test_helper.rb` | Modify | Add `run_bundle` and `run_bundle!` helpers |
| `test/containers/test_bundle_install.rb` | Rewrite | Expand from spike to cover all Bundler integration scenarios |
| `test/containers/test_gem_install.rb` | Rewrite | Expand from spike to cover all RubyGems plugin scenarios |
| `test/containers/test_bundler_inline.rb` | Create | Bundler inline (gemfile block) test |
| `test/containers/test_plugin_root_deps.rb` | Create | plugins.rb preamble test (Bundler::Plugin.root workaround) |
| `test/integration_test.rb` | Delete | Replaced by container tests |
| `test/rubygems_plugin_test.rb` | Modify | Remove `RubygemsPluginIntegrationTest` class (keep unit test classes) |

## Test Migration Map

Each old test maps to a container test method:

**`test/integration_test.rb` → `test/containers/test_bundle_install.rb`:**

| Old test | New method | Notes |
|----------|-----------|-------|
| `test_basic_install` | Already done in spike | |
| `test_multiple_gems` | `test_multiple_gems` | Three gems, all install |
| `test_lockfile_correct` | `test_lockfile_format` | Assert PLUGIN SOURCE, type, version |
| `test_lockfile_round_trip` | `test_lockfile_idempotent` | Two installs, same lockfile |
| `test_gem_loadable` | Already done in spike (asserts `bundle exec ruby -e`) | |
| `test_alongside_rubygems_source` | `test_mixed_sources` | Vault + rubygems.org together |
| `test_subset_of_vault` | `test_partial_vault_install` | 3 in vault, only 2 in Gemfile |
| `test_dependency_resolution` | `test_intra_vault_dependency` | gem A depends on gem B, both in vault |
| `test_multi_version_resolution` | `test_version_constraint` | Two versions, `~> 2.0` picks correct one |
| `test_version_constraint_unsatisfied` | `test_unsatisfied_constraint` | Expect failure |

**`test/integration_test.rb` → `test/containers/test_bundler_inline.rb`:**

| Old test | New method | Notes |
|----------|-----------|-------|
| `test_bundler_inline` | `test_bundler_inline_with_vault` | No `plugin path:` hack needed — gem is installed |

**`test/integration_test.rb` → `test/containers/test_plugin_root_deps.rb`:**

| Old test | New method | Notes |
|----------|-----------|-------|
| `test_plugins_rb_makes_plugin_root_deps_activatable` | `test_plugin_root_specs_discoverable` | Same preamble-extraction approach |

**`test/rubygems_plugin_test.rb` → `test/containers/test_gem_install.rb`:**

| Old test | New method | Notes |
|----------|-----------|-------|
| `test_gem_install_from_vault` | Already done in spike | |
| `test_gem_install_verbose_shows_vault_messages` | `test_verbose_output` | `--verbose` flag shows vault messages |
| `test_gem_install_file_uri_source` | `test_file_uri_source` | `file://` prefix works |

---

### Task 1: Add bundle helpers to test_helper.rb

**Files:**
- Modify: `test/containers/test_helper.rb`

The existing Bundler tests in `test_bundle_install.rb` call `Open3.capture2e("bundle", "install", chdir:)` inline. Multiple tests need this — extract `run_bundle` and `run_bundle!` into the helper, matching the old tests' pattern.

- [ ] **Step 1: Add run_bundle and run_bundle! to ContainerTestHelper**

```ruby
# In test/containers/test_helper.rb, add to ContainerTestHelper before `private`:

def run_bundle(*args, chdir:)
  Open3.capture2e("bundle", *args, chdir: chdir.to_s)
end

def run_bundle!(*args, chdir:)
  output, status = run_bundle(*args, chdir: chdir)
  assert_predicate status, :success?, "bundle #{args.join(" ")} failed:\n#{output}"
  [output, status]
end
```

- [ ] **Step 2: Update test_bundle_install.rb to use the helper**

Replace the inline `Open3.capture2e("bundle", ...)` calls in the existing spike test with `run_bundle` / `run_bundle!`.

- [ ] **Step 3: Run container tests to verify refactor**

Run: `bundle exec rake test:containers`
Expected: both existing tests still pass.

- [ ] **Step 4: Commit**

```bash
git add test/containers/test_helper.rb test/containers/test_bundle_install.rb
git commit -m "Extract run_bundle helpers into container test helper"
```

---

### Task 2: Expand test_bundle_install.rb with all Bundler scenarios

**Files:**
- Rewrite: `test/containers/test_bundle_install.rb`

Add the remaining 8 Bundler integration tests. Each test follows the same pattern: build fixture gems, create vault, write Gemfile, `run_bundle!("install", chdir:)`, assert results.

- [ ] **Step 1: Write test_multiple_gems**

```ruby
def test_multiple_gems
  gem1 = build_gem("alpha_vault", "1.0.0", dir: @gem_build_dir)
  gem2 = build_gem("beta_vault", "2.0.0", dir: @gem_build_dir / "b")
  gem3 = build_gem("gamma_vault", "3.0.0", dir: @gem_build_dir / "c")

  vault_path = create_vault(@workdir / "multi.gemv", gem1, gem2, gem3)

  (@workdir / "Gemfile").write(<<~GEMFILE)
    source "#{vault_path}", type: :vault do
      gem "alpha_vault"
      gem "beta_vault"
      gem "gamma_vault"
    end
  GEMFILE

  run_bundle!("install", chdir: @workdir)

  %w[alpha_vault-1.0.0 beta_vault-2.0.0 gamma_vault-3.0.0].each do |name|
    dirs = @workdir.glob("**/gems/#{name}")
    refute_empty dirs, "Expected #{name} to be installed"
  end
end
```

- [ ] **Step 2: Write test_lockfile_format**

```ruby
def test_lockfile_format
  gem_path = build_gem("locktest", "1.0.0", dir: @gem_build_dir)
  vault_path = create_vault(@workdir / "lock.gemv", gem_path)

  (@workdir / "Gemfile").write(<<~GEMFILE)
    source "#{vault_path}", type: :vault do
      gem "locktest"
    end
  GEMFILE

  run_bundle!("install", chdir: @workdir)

  lockfile = (@workdir / "Gemfile.lock").read
  assert_includes lockfile, "PLUGIN SOURCE"
  assert_includes lockfile, "type: vault"
  assert_includes lockfile, "locktest (1.0.0)"
end
```

- [ ] **Step 3: Write test_lockfile_idempotent**

```ruby
def test_lockfile_idempotent
  gem_path = build_gem("roundtrip", "1.0.0", dir: @gem_build_dir)
  vault_path = create_vault(@workdir / "rt.gemv", gem_path)

  (@workdir / "Gemfile").write(<<~GEMFILE)
    source "#{vault_path}", type: :vault do
      gem "roundtrip"
    end
  GEMFILE

  run_bundle!("install", chdir: @workdir)
  lockfile1 = (@workdir / "Gemfile.lock").read

  run_bundle!("install", chdir: @workdir)
  lockfile2 = (@workdir / "Gemfile.lock").read

  assert_equal lockfile1, lockfile2, "Lockfile changed after second install"
end
```

- [ ] **Step 4: Write test_mixed_sources**

```ruby
def test_mixed_sources
  gem_path = build_gem("vaultgem", "1.0.0", dir: @gem_build_dir)
  vault_path = create_vault(@workdir / "mixed.gemv", gem_path)

  (@workdir / "Gemfile").write(<<~GEMFILE)
    source "https://rubygems.org"

    source "#{vault_path}", type: :vault do
      gem "vaultgem"
    end
  GEMFILE

  output, status = run_bundle("install", chdir: @workdir)
  assert_predicate status, :success?, "bundle install with mixed sources failed:\n#{output}"
  assert_match(/Bundle complete!/, output)
end
```

- [ ] **Step 5: Write test_partial_vault_install**

```ruby
def test_partial_vault_install
  gem1 = build_gem("want1", "1.0.0", dir: @gem_build_dir)
  gem2 = build_gem("want2", "1.0.0", dir: @gem_build_dir / "w2")
  gem3 = build_gem("skipme", "1.0.0", dir: @gem_build_dir / "sk")

  vault_path = create_vault(@workdir / "subset.gemv", gem1, gem2, gem3)

  (@workdir / "Gemfile").write(<<~GEMFILE)
    source "#{vault_path}", type: :vault do
      gem "want1"
      gem "want2"
    end
  GEMFILE

  run_bundle!("install", chdir: @workdir)

  refute_empty @workdir.glob("**/gems/want1-1.0.0")
  refute_empty @workdir.glob("**/gems/want2-1.0.0")
  assert_empty @workdir.glob("**/gems/skipme-1.0.0"), "skipme should not be installed"
end
```

- [ ] **Step 6: Write test_intra_vault_dependency**

```ruby
def test_intra_vault_dependency
  gem_b = build_gem("depb", "1.0.0", dir: @gem_build_dir / "b")
  gem_a = build_gem("depa", "1.0.0", dir: @gem_build_dir,
    files: {"lib/depa.rb" => "require 'depb'; module Depa; end"},
    dependencies: [["depb", "~> 1.0"]])

  vault_path = create_vault(@workdir / "deps.gemv", gem_a, gem_b)

  (@workdir / "Gemfile").write(<<~GEMFILE)
    source "#{vault_path}", type: :vault do
      gem "depa"
      gem "depb"
    end
  GEMFILE

  output, status = run_bundle("install", chdir: @workdir)
  assert_predicate status, :success?, "bundle install with dependencies failed:\n#{output}"

  refute_empty @workdir.glob("**/gems/depa-1.0.0")
  refute_empty @workdir.glob("**/gems/depb-1.0.0")
end
```

- [ ] **Step 7: Write test_version_constraint**

```ruby
def test_version_constraint
  gem_v1 = build_gem("multiver", "1.0.0", dir: @gem_build_dir / "v1",
    files: {"lib/multiver.rb" => 'module Multiver; VERSION = "1.0.0"; end'})
  gem_v2 = build_gem("multiver", "2.0.0", dir: @gem_build_dir / "v2",
    files: {"lib/multiver.rb" => 'module Multiver; VERSION = "2.0.0"; end'})

  vault_path = create_vault(@workdir / "mv.gemv", gem_v1, gem_v2)

  (@workdir / "Gemfile").write(<<~GEMFILE)
    source "#{vault_path}", type: :vault do
      gem "multiver", "~> 2.0"
    end
  GEMFILE

  run_bundle!("install", chdir: @workdir)

  refute_empty @workdir.glob("**/gems/multiver-2.0.0")
  assert_empty @workdir.glob("**/gems/multiver-1.0.0"), "1.0.0 should not be installed"

  output, status = run_bundle("exec", "ruby", "-e",
    "require 'multiver'; puts Multiver::VERSION", chdir: @workdir)
  assert_predicate status, :success?, "bundle exec failed:\n#{output}"
  assert_match(/2\.0\.0/, output)
end
```

- [ ] **Step 8: Write test_unsatisfied_constraint**

```ruby
def test_unsatisfied_constraint
  gem_path = build_gem("constrained", "1.0.0", dir: @gem_build_dir)
  vault_path = create_vault(@workdir / "constraint.gemv", gem_path)

  (@workdir / "Gemfile").write(<<~GEMFILE)
    source "#{vault_path}", type: :vault do
      gem "constrained", "~> 2.0"
    end
  GEMFILE

  output, status = run_bundle("install", chdir: @workdir)
  refute_predicate status, :success?, "Expected bundle install to fail with unsatisfied constraint"
  assert_match(/could not find/i, output)
end
```

- [ ] **Step 9: Run container tests**

Run: `bundle exec rake test:containers`
Expected: all tests in `test_bundle_install.rb` pass (9 total methods).

- [ ] **Step 10: Commit**

```bash
git add test/containers/test_bundle_install.rb
git commit -m "Add full Bundler integration suite to container tests"
```

---

### Task 3: Expand test_gem_install.rb with RubyGems plugin scenarios

**Files:**
- Modify: `test/containers/test_gem_install.rb`

Add verbose output and file:// URI tests from `RubygemsPluginIntegrationTest`.

- [ ] **Step 1: Write test_verbose_output**

```ruby
def test_verbose_output
  gem_path = build_gem("vault_verbose", "1.0.0", dir: @gem_build_dir,
    files: {"lib/vault_verbose.rb" => 'module VaultVerbose; VERSION = "1.0.0"; end'})

  vault_path = create_vault(@workdir / "verbose.gemv", gem_path)

  env = gem_env_for(@gem_home)
  output, status = Open3.capture2e(
    env,
    "gem", "install", "--verbose", "--source", vault_path.to_s,
    "--no-document", "vault_verbose",
  )

  assert_predicate status, :success?, "gem install --verbose failed:\n#{output}"
  assert_match(/Loading .* specs from vault at/, output)
  assert_match(/Extracting vault_verbose-1\.0\.0\.gem from vault at/, output)
end
```

- [ ] **Step 2: Write test_file_uri_source**

```ruby
def test_file_uri_source
  gem_path = build_gem("vault_fileuri", "1.0.0", dir: @gem_build_dir,
    files: {"lib/vault_fileuri.rb" => 'module VaultFileuri; VERSION = "1.0.0"; end'})

  vault_path = create_vault(@workdir / "fileuri.gemv", gem_path)

  env = gem_env_for(@gem_home)
  output, status = Open3.capture2e(
    env,
    "gem", "install", "--source", "file://#{vault_path}",
    "--no-document", "vault_fileuri",
  )

  assert_predicate status, :success?, "gem install with file:// URI failed:\n#{output}"
  assert_match(/installed vault_fileuri/i, output)
end
```

- [ ] **Step 3: Run container tests**

Run: `bundle exec rake test:containers`
Expected: all `test_gem_install.rb` tests pass (3 total methods).

- [ ] **Step 4: Commit**

```bash
git add test/containers/test_gem_install.rb
git commit -m "Add verbose and file:// URI tests to container gem install suite"
```

---

### Task 4: Write test_bundler_inline.rb

**Files:**
- Create: `test/containers/test_bundler_inline.rb`

The inline test is special: `bundler/inline` handles its own plugin installation. In the container, the `bundler-source-vault` gem is already installed, so we don't need the `plugin "...", path:` hack. The inline gemfile block should discover the plugin automatically.

- [ ] **Step 1: Write the test file**

```ruby
require_relative "test_helper"

class BundlerInlineTest < Minitest::Test
  include ContainerTestHelper

  def setup
    install_gemvault!
    @workdir = Pathname(Dir.mktmpdir("bundler_inline_test"))
    @gem_build_dir = @workdir / "gems"
    @gem_build_dir.mkpath
  end

  def teardown
    @workdir.rmtree
  end

  def test_bundler_inline_with_vault
    gem_path = build_gem("inline_gem", "1.0.0", dir: @gem_build_dir,
      files: {"lib/inline_gem.rb" => 'module InlineGem; VERSION = "1.0.0"; end'})

    vault_path = create_vault(@workdir / "inline.gemv", gem_path)

    script = <<~RUBY
      require "bundler/inline"

      gemfile(true) do
        source "#{vault_path}", type: :vault do
          gem "inline_gem"
        end
      end

      require "inline_gem"
      puts InlineGem::VERSION
    RUBY

    script_path = @workdir / "inline_test.rb"
    script_path.write(script)

    output, status = Open3.capture2e("ruby", script_path.to_s, chdir: @workdir.to_s)
    assert_predicate status, :success?, "bundler/inline failed:\n#{output}"
    assert_match(/1\.0\.0/, output)
  end
end
```

- [ ] **Step 2: Run container tests**

Run: `bundle exec rake test:containers`
Expected: `test_bundler_inline.rb` passes. If `bundler/inline` cannot auto-discover the plugin from installed gems, this test will reveal it — that itself is a valuable finding.

- [ ] **Step 3: Commit**

```bash
git add test/containers/test_bundler_inline.rb
git commit -m "Add bundler/inline container test"
```

---

### Task 5: Write test_plugin_root_deps.rb

**Files:**
- Create: `test/containers/test_plugin_root_deps.rb`

This test verifies the `shim/plugins.rb` preamble that patches `Gem::Specification.dirs` to include `Bundler::Plugin.root`. The test extracts the preamble (code before the first `require` line), fakes a Plugin.root with a phantom gem spec, runs the preamble, and asserts the phantom dep becomes discoverable.

- [ ] **Step 1: Write the test file**

```ruby
require_relative "test_helper"

class PluginRootDepsTest < Minitest::Test
  include ContainerTestHelper

  def setup
    install_gemvault!
    @workdir = Pathname(Dir.mktmpdir("plugin_root_test"))
  end

  def teardown
    @workdir.rmtree
  end

  def test_plugin_root_specs_discoverable
    fake_root = @workdir / "fake_plugin_root"
    fake_specs = fake_root / "specifications"
    fake_specs.mkpath

    plugins_rb = GEM_SOURCE.join("shim", "plugins.rb").read
    preamble = plugins_rb.lines.take_while { |l| !l.match?(/^require\b/) }.join

    preamble_path = @workdir / "preamble.rb"
    preamble_path.write(preamble)

    script_path = @workdir / "test_plugin_root_deps.rb"
    script_path.write(<<~RUBY)
      require "bundler"

      fake_spec = Gem::Specification.new do |s|
        s.name = "phantom_dep"
        s.version = "1.0.0"
        s.summary = "Simulated plugin dependency"
        s.authors = ["Test"]
        s.files = []
      end
      File.write("#{fake_specs / "phantom_dep-1.0.0.gemspec"}", fake_spec.to_ruby)

      begin
        Gem::Specification.find_by_name("phantom_dep")
        $stderr.puts "SETUP ERROR: phantom_dep already visible"
        exit 2
      rescue Gem::MissingSpecError
        # Expected
      end

      module Bundler::Plugin
        remove_method :root if method_defined?(:root)
        define_method(:root) { Pathname.new("#{fake_root}") }
        module_function :root
      end

      load "#{preamble_path}"

      begin
        Gem::Specification.find_by_name("phantom_dep")
        puts "PASS"
      rescue Gem::MissingSpecError
        $stderr.puts "FAIL: phantom_dep not findable after plugins.rb preamble"
        exit 1
      end
    RUBY

    output, status = Open3.capture2e("ruby", script_path.to_s)
    assert_predicate status, :success?,
      "plugins.rb should make Plugin.root deps findable:\n#{output}"
    assert_match(/PASS/, output)
  end
end
```

- [ ] **Step 2: Run container tests**

Run: `bundle exec rake test:containers`
Expected: `test_plugin_root_deps.rb` passes.

- [ ] **Step 3: Commit**

```bash
git add test/containers/test_plugin_root_deps.rb
git commit -m "Add plugin root dependency discovery container test"
```

---

### Task 6: Remove old integration tests

**Files:**
- Delete: `test/integration_test.rb`
- Modify: `test/rubygems_plugin_test.rb` (remove `RubygemsPluginIntegrationTest`, keep other 3 classes)

- [ ] **Step 1: Delete test/integration_test.rb**

```bash
rm test/integration_test.rb
```

- [ ] **Step 2: Remove RubygemsPluginIntegrationTest from rubygems_plugin_test.rb**

Delete lines 281-378 (`class RubygemsPluginIntegrationTest ... end`). Keep:
- `RubygemsSourceVaultTest` (lines 9-184) — unit tests for `Gem::Source::Vault`
- `RubygemsResolverVaultSetTest` (lines 186-249) — unit tests for `Gem::Resolver::VaultSet`
- `RubygemsPluginMonkeyPatchTest` (lines 251-279) — unit tests for monkey-patches

- [ ] **Step 3: Run all test suites to confirm nothing broke**

Run: `bundle exec rake test && bundle exec rspec && bundle exec rake test:containers`
Expected:
- `rake test`: ~107 runs (was 122 — 12 integration + 3 rubygems integration removed)
- `rspec`: 1 example, 0 failures
- `rake test:containers`: all container tests pass

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Remove old integration tests, replaced by container tests"
```

---

### Task 7: Rebuild cached Docker image

After all test files are finalized, rebuild the cached image so CI can use it.

- [ ] **Step 1: Rebuild the image**

Run: `bundle exec rake test:containers:build`

- [ ] **Step 2: Run full container suite with cached image**

Run: `bundle exec rake test:containers`
Expected: all container tests pass, output shows `(cached)`.

- [ ] **Step 3: Final verification — all three suites green**

```bash
bundle exec rake test
bundle exec rspec
bundle exec rake test:containers
```

All three must pass with zero failures.
