#!/usr/bin/env bash
# Full-fidelity host reproduction of issue #31, mirroring
# spec/integration/vault_installed_executable_spec.rb outside podman: the
# tree's own gemvault and bundler-source-vault gems, bundler 4.0.17 (the
# version the integration image pins), a real .gemv vault, and a real
# executable installed from it with `gem install --source`.
#
# Sequence: ambient shim -> vaulted project bundle install (records gem-home
# paths in .bundle/plugin/index, leaves .bundle/plugin/gems empty) ->
# gem install --source vault vault_tool -> vault_tool runs (control) ->
# ambient shim uninstalled -> the reported sequence again -> vault_tool dies
# in SourceList#add_plugin_source with `undefined method 'new' for nil`.
#
# Needs a ruby satisfying gemvault.gemspec's required_ruby_version (pass its
# prefix as DEMO_RUBY_PREFIX; defaults to `rbenv prefix 3.4.9`), and network
# access to fetch bundler 4.0.17 and command_kit from rubygems.org. Work
# happens under tmp/issue31_demo, removed on exit; set KEEP=1 to inspect the
# wreck afterwards. Serves a gem index on port 8808.
set -e

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ROOT="$REPO/tmp/issue31_demo"

RUBY_PREFIX="${DEMO_RUBY_PREFIX:-$(rbenv prefix 3.4.9 2>/dev/null || true)}"
if [ -z "$RUBY_PREFIX" ] || [ ! -x "$RUBY_PREFIX/bin/ruby" ]; then
  echo "Set DEMO_RUBY_PREFIX to a ruby install satisfying gemvault.gemspec's required_ruby_version" >&2
  exit 1
fi

rm -rf "$ROOT"
mkdir -p "$ROOT/gemhome" "$ROOT/tmp" "$ROOT/index/gems" "$ROOT/src" "$ROOT/home"

export HOME="$ROOT/home"
export GEM_HOME="$ROOT/gemhome"
export GEM_PATH="$ROOT/gemhome"
export PATH="$GEM_HOME/bin:$RUBY_PREFIX/bin:/usr/bin:/bin"
export TMPDIR="$ROOT/tmp"
unset BUNDLE_GEMFILE RUBYOPT GEM_ROOT IRBRC

cleanup() {
  [ -n "${HTTPD_PID:-}" ] && kill "$HTTPD_PID" 2>/dev/null
  [ -n "${KEEP:-}" ] || rm -rf "$ROOT"
  true
}
trap cleanup EXIT

ruby -v
gem install --no-document bundler -v 4.0.17 >/dev/null

ruby -e '
module RSpec; def self.configure; end; end
require File.expand_path("spec/support/gem_index", ARGV[0])
require File.expand_path("spec/support/fixture_script", ARGV[0])
require File.expand_path("spec/support/vault_installed_executable", ARGV[0])
File.write(File.join(ARGV[1], "deps.rb"), GemIndex::DEPS_RB)
File.write(File.join(ARGV[1], "mkindex.rb"), GemIndexFiles::MKINDEX_RB)
File.write(File.join(ARGV[1], "httpd.rb"), GemIndex::HTTPD_RB)
fixtures = FixtureScript.preamble(
  gems: [["vault_test_gem", "1.0.0"], [VaultInstalledExecutable::TOOL_GEM, "1.0.0"]],
  files: { VaultInstalledExecutable::TOOL_GEM => VaultInstalledExecutable::TOOL_FILES },
)
File.write(File.join(ARGV[1], "fixtures.sh"), fixtures)
' "$REPO" "$ROOT"

cp -r "$REPO/lib" "$REPO/exe" "$REPO/shim" "$REPO/gemvault.gemspec" \
  "$REPO/README.md" "$REPO/LICENSE.txt" "$REPO/Rakefile" "$ROOT/src/"
(cd "$ROOT/src" && gem build -q gemvault.gemspec >/dev/null)
(cd "$ROOT/src/shim" && gem build -q bundler-source-vault.gemspec >/dev/null)

gem install --no-document "$ROOT"/src/gemvault-*.gem >/dev/null
gem install --local --no-document "$ROOT"/src/shim/bundler-source-vault-*.gem >/dev/null

cp "$ROOT"/src/*.gem "$ROOT"/src/shim/*.gem "$ROOT/index/gems/"
ruby "$ROOT/deps.rb" "$ROOT/index/gems"
ruby "$ROOT/mkindex.rb" "$ROOT/index"
ruby "$ROOT/httpd.rb" "$ROOT/index" 8808 &
HTTPD_PID=$!
for _ in $(seq 1 100); do
  ruby -rsocket -e 'TCPSocket.new("127.0.0.1", 8808).close' 2>/dev/null && break
  sleep 0.1
done

source "$ROOT/fixtures.sh"

cd "$WORKDIR"
cat > Gemfile <<GEMFILE
source "http://127.0.0.1:8808"

source "$WORKDIR/test.gemv", type: :vault do
  gem "vault_test_gem"
end
GEMFILE

bundle config set --local path vendor >/dev/null
bundle install

echo "=== plugin index after bundle install ==="
cat .bundle/plugin/index
echo "=== plugin root gems dir ==="
ls .bundle/plugin/gems 2>/dev/null || echo "(never populated)"

gem install --no-document --source "$WORKDIR/test.gemv" vault_tool

echo "=== control: tool on the intact machine ==="
vault_tool

echo "=== decay: the ambient shim leaves the gem home ==="
gem uninstall -a -I bundler-source-vault >/dev/null

echo "=== reported sequence on the decayed machine (expected: NoMethodError) ==="
gem install --no-document --source "$WORKDIR/test.gemv" vault_tool
if vault_tool; then
  echo "UNEXPECTED: the tool ran on the decayed machine" >&2
  exit 1
fi
echo "=== reproduced: the tool crashed the way issue #31 reports ==="
