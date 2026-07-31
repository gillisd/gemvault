require "bundler/gem_tasks"

require "minitest/test_task"

Minitest::TestTask.create do |t|
  t.test_globs = ["test/*_test.rb"]
end

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

RSpec::Core::RakeTask.new("spec:core") do |t|
  t.rspec_opts = "--tag ~integration"
end

RSpec::Core::RakeTask.new("spec:integration") do |t|
  t.rspec_opts = "--tag integration"
end

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "gempilot/version_task"
Gempilot::VersionTask.new

require "rubycritic/rake_task"
RubyCritic::RakeTask.new

require "digest"
require_relative "spec/support/container_helper"
require_relative "spec/support/container_image"

# What the image is built from. ContainerImage feeds this to podman as a build
# arg, because the bind mount the Dockerfile reads is invisible to podman's
# layer cache key.
def image_source_digest
  fingerprints = FileList["lib/**/*", "exe/*", "gemvault.gemspec"]
                 .select { |path| File.file?(path) }.sort
                 .map { |path| "#{path} #{Digest::SHA256.hexdigest(File.binread(path))}" }
  Digest::SHA256.hexdigest(fingerprints.join("\n"))
end

def cached_image
  ContainerImage.new(name: ContainerHelper::CACHED_IMAGE, root: __dir__, digest: image_source_digest)
end

namespace :spec do
  desc "Build cached container image with gemvault pre-installed"
  task(:build) { cached_image.build }

  desc "Build the cached image unless it already exists"
  task(:setup) { cached_image.ensure_built }

  desc "Remove test containers and the cached image"
  task(:teardown) { cached_image.destroy }
end

directory "pkg" do
  mkdir "pkg"
end

namespace :shim do
  Bundler::GemHelper.install_tasks dir: "shim", name: "bundler-source-vault"
  CLOBBER.include "shim/pkg"

  Rake::Task[:build].enhance ["pkg"] do
    FileList["shim/pkg/*.gem"].each do |g|
      mv g, "pkg", verbose: false
    end
  end
end

Rake::Task[:spec].enhance ["spec:setup"]
Rake::Task["spec:integration"].enhance ["spec:setup"]
Rake::Task[:build].enhance ["shim:build"]
Rake::Task[:release].enhance ["shim:release"]
Rake::Task[:clobber].enhance ["spec:teardown"]

task default: [:test, :spec, :rubocop, :rubycritic]
