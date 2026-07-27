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

require "digest"
require_relative "spec/support/container_helper"

CACHED_IMAGE = ContainerHelper::CACHED_IMAGE

# Dockerfile.test reads the tree through a bind mount, whose contents podman
# does not fold into its layer cache key. Feeding this digest in as a build arg
# is what makes `rake spec:build` notice that the source changed.
def image_source_digest
  fingerprints = FileList["lib/**/*", "exe/*", "gemvault.gemspec"]
                 .select { |path| File.file?(path) }.sort
                 .map { |path| "#{path} #{Digest::SHA256.hexdigest(File.binread(path))}" }
  Digest::SHA256.hexdigest(fingerprints.join("\n"))
end

def cached_image_exists?
  system("podman", "image", "exists", CACHED_IMAGE, out: File::NULL, err: File::NULL)
end

def build_cached_image
  sh "podman", "build", "--network=host", "-v", "#{__dir__}:/src:ro",
     "--build-arg", "SOURCE_DIGEST=#{image_source_digest}",
     "-t", CACHED_IMAGE, "-f", "Dockerfile.test", "."
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

task default: [:test, :spec, :rubocop]
