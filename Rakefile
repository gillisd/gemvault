require "bundler/gem_tasks"

require "minitest/test_task"

Minitest::TestTask.create do |t|
  t.test_globs = ["test/*_test.rb"]
end

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "gempilot/version_task"
Gempilot::VersionTask.new

CACHED_IMAGE = "gemvault-test:latest".freeze

namespace :spec do
  desc "Build cached container image with gemvault pre-installed"
  task :build do
    sh "podman", "build",
       "--network=host",
       "-t", CACHED_IMAGE,
       "-f", "Dockerfile.test",
       "."
  end
end

namespace :shim do
  Bundler::GemHelper.install_tasks dir: "shim", name: "bundler-source-vault"
  CLOBBER.include 'shim/pkg'
end

Rake::Task[:build].enhance ['shim:build']
Rake::Task[:release].enhance ['shim:release']

task default: [:test, :spec, :rubocop]
