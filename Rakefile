# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

namespace :shim do
  desc "Build the bundler-source-vault shim gem"
  task :build do
    Dir.chdir("shim") { sh "gem build bundler-source-vault.gemspec" }
  end
end

task default: :test
