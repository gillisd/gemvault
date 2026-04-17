# Development-only plugins.rb. The published version lives in shim/plugins.rb
# and ships inside the bundler-source-vault gem.
#
# This file exists so `plugin "bundler-source-vault", path: "."` works during
# local development and testing.

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))

load File.expand_path("shim/plugins.rb", __dir__)
