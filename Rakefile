require "bundler/gem_tasks"

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "gempilot/version_task"
Gempilot::VersionTask.new

namespace :shim do
  desc "Build the bundler-source-vault shim gem"
  task :build do
    Dir.chdir("shim") { sh "gem build bundler-source-vault.gemspec" }
  end
end

task default: [:spec, :rubocop]
