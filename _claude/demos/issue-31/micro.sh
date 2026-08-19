#!/usr/bin/env bash
# Minimal host proof of issue #31's bundler-side mechanism, isolated from
# gemvault entirely: a throwaway plugin gem stands in for the shim.
#
# Proves, with whatever ruby is on PATH (its bundler must be >= 2.6.0, where
# rubygems/rubygems commit 0c6ad3ecbb added the load_plugin guard):
#
#   1. `bundle install` with the plugin installed as an ambient gem records
#      the gem home's absolute paths in the project's .bundle/plugin/index
#      and never populates .bundle/plugin/gems.
#   2. bundler/setup works while the ambient copy is intact.
#   3. Once the ambient copy is uninstalled, bundler/setup dies with
#      `undefined method 'new' for nil` in SourceList#add_plugin_source --
#      the guard's warning is swallowed by Bundler.ui.silence.
#
# Work happens under tmp/issue31_micro, removed on exit; set KEEP=1 to
# inspect the wreck afterwards. Serves a gem index on port 8809.
set -e

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$REPO/tmp/issue31_micro"
rm -rf "$T"
mkdir -p "$T/gemhome" "$T/index/gems" "$T/app" "$T/plugin_src" "$T/home"

RUBY_BINDIR=$(ruby -e 'print RbConfig::CONFIG["bindir"]')

export HOME="$T/home"
export GEM_HOME="$T/gemhome"
export GEM_PATH="$T/gemhome"
export PATH="$GEM_HOME/bin:$RUBY_BINDIR:/usr/bin:/bin"
export TMPDIR="$T"
unset BUNDLE_GEMFILE RUBYOPT

cleanup() {
  [ -n "${HTTPD_PID:-}" ] && kill "$HTTPD_PID" 2>/dev/null
  [ -n "${KEEP:-}" ] || rm -rf "$T"
  true
}
trap cleanup EXIT

ruby -v

ruby -e '
module RSpec; def self.configure; end; end
require File.expand_path("spec/support/gem_index", ARGV[0])
File.write(File.join(ARGV[1], "mkindex.rb"), GemIndexFiles::MKINDEX_RB)
File.write(File.join(ARGV[1], "httpd.rb"), GemIndex::HTTPD_RB)
' "$REPO" "$T"

cd "$T/plugin_src"
cat > plugins.rb <<'PLUGINS'
class FakeVaultSource
end
Bundler::Plugin::API.source("fake", FakeVaultSource)
PLUGINS
cat > bundler-source-fake.gemspec <<'GEMSPEC'
Gem::Specification.new do |s|
  s.name = "bundler-source-fake"
  s.version = "1.0.0"
  s.summary = "test"
  s.authors = ["test"]
  s.license = "MIT"
  s.homepage = "https://example.com"
  s.files = ["plugins.rb"]
  s.require_paths = ["."]
end
GEMSPEC
gem build -q bundler-source-fake.gemspec >/dev/null

gem install --local --no-document "$T"/plugin_src/bundler-source-fake-1.0.0.gem >/dev/null
echo "=== ambient plugin installed at ==="
ls -d "$GEM_HOME"/gems/bundler-source-fake-1.0.0

cp "$T"/plugin_src/*.gem "$T/index/gems/"
ruby "$T/mkindex.rb" "$T/index"
ruby "$T/httpd.rb" "$T/index" 8809 &
HTTPD_PID=$!
for _ in $(seq 1 100); do
  ruby -rsocket -e 'TCPSocket.new("127.0.0.1", 8809).close' 2>/dev/null && break
  sleep 0.1
done

cd "$T/app"
cat > Gemfile <<GEMFILE
source "http://127.0.0.1:8809"

source "$T/app", type: :fake do
end
GEMFILE

bundle install
echo "=== plugin index after bundle install ==="
cat .bundle/plugin/index
echo "=== plugin root gems dir ==="
ls .bundle/plugin/gems 2>/dev/null || echo "(never populated)"

echo "=== control: bundler/setup on the intact machine ==="
ruby -e 'require "bundler/setup"; puts "setup ok"'

echo "=== decay: ambient copy leaves the gem home ==="
gem uninstall -a -I -x bundler-source-fake >/dev/null

echo "=== bundler/setup on the decayed machine (expected: NoMethodError) ==="
if ruby -e 'require "bundler/setup"; puts "setup ok"'; then
  echo "UNEXPECTED: setup succeeded on the decayed machine" >&2
  exit 1
fi
echo "=== reproduced: bundler/setup crashed the way issue #31 reports ==="
