require "bundler/gem_tasks"

require "minitest/test_task"

Minitest::TestTask.create do |t|
  t.test_globs = ["test/*_test.rb"]
end

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new("spec:host") do |t|
  t.pattern = "spec/*_spec.rb"
end

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "gempilot/version_task"
Gempilot::VersionTask.new

BASE_IMAGE = "docker.io/library/ruby:4.0.1-slim"
CACHED_IMAGE = "gemvault-test:latest"

def container_image
  `podman image exists #{CACHED_IMAGE} 2>&1`
  $?.success? ? CACHED_IMAGE : BASE_IMAGE
end

namespace :spec do
  desc "Build cached container image with gemvault pre-installed"
  task :build do
    sh "podman", "build",
      "--network=host",
      "-t", CACHED_IMAGE,
      "-f", "Dockerfile.test",
      "."
  end

  desc "Run container specs (requires Podman)"
  task :containers do
    image = container_image
    spec_files = FileList["spec/containers/*_spec.rb"]
    abort "No container specs found" if spec_files.empty?

    puts "Using image: #{image}"
    puts image == CACHED_IMAGE ? "(cached)" : "(no cache — run `rake spec:build` to speed this up)"

    results = spec_files.map do |spec_file|
      name = File.basename(spec_file, "_spec.rb")
      puts "\n#{"=" * 60}"
      puts "Running #{name} in container..."
      puts "=" * 60

      cmd = [
        "podman", "run", "--rm", "--network=host",
        "-v", "#{Dir.pwd}:/gem:ro",
        image,
        "ruby", "/gem/#{spec_file}",
      ]

      system(*cmd)
      [$?, name]
    end

    puts "\n#{"=" * 60}"
    puts "Container spec results:"
    puts "=" * 60
    results.each do |status, name|
      mark = status.success? ? "PASS" : "FAIL"
      puts "  #{mark}  #{name}"
    end

    failures = results.reject { |status, _| status.success? }
    abort "\n#{failures.length} container spec(s) failed" unless failures.empty?
    puts "\nAll #{results.length} container specs passed"
  end
end

desc "Run all specs (host + container)"
task spec: ["spec:host", "spec:containers"]

namespace :shim do
  desc "Build the bundler-source-vault shim gem"
  task :build do
    Dir.chdir("shim") { sh "gem build bundler-source-vault.gemspec" }
  end
end

task default: [:test, :spec, :rubocop]
