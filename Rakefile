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

CACHED_IMAGE = "gemvault-test:latest"

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
  desc "Build the bundler-source-vault shim gem"
  task :build do
    Dir.chdir("shim") { sh "gem build bundler-source-vault.gemspec" }
  end
end

task default: [:test, :spec, :rubocop]
