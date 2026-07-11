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

def cached_image_exists?
  system("podman", "image", "exists", CACHED_IMAGE, out: File::NULL, err: File::NULL)
end

def build_cached_image
  sh "podman", "build", "--network=host", "-t", CACHED_IMAGE, "-f", "Dockerfile.test", "."
end

def destroy_cached_image
  strays = `podman ps -aq --filter ancestor=#{CACHED_IMAGE}`.split
  sh "podman", "rm", "-f", *strays unless strays.empty?
  sh "podman", "rmi", CACHED_IMAGE
end

namespace :spec do
  desc "Build cached container image with gemvault pre-installed"
  task(:build) { build_cached_image }

  desc "Build the cached image unless it already exists"
  task(:setup) { build_cached_image unless cached_image_exists? }

  desc "Remove test containers and the cached image"
  task(:teardown) { destroy_cached_image if cached_image_exists? }
end

namespace :shim do
  Bundler::GemHelper.install_tasks dir: "shim", name: "bundler-source-vault"
  CLOBBER.include "shim/pkg"
end

Rake::Task[:spec].enhance ["spec:setup"]
Rake::Task[:build].enhance ["shim:build"]
Rake::Task[:release].enhance ["shim:release"]
Rake::Task[:clobber].enhance ["spec:teardown"]

task default: [:test, :spec, :rubocop]
