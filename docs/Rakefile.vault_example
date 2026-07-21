require "rake/clean"
require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "open3"

def gemvault_contains?(gemvault_file, gem)
  response, status = Open3.capture2e("gemvault", "list", gemvault_file)
  unless status.success?
    warn "Failed to list gems in vault:"
    warn response
    exit 1
  end
  gems = response.lines(chomp: true)
  gemname_and_version = Pathname(gem).basename.sub_ext("").to_s
  gems.include?(gemname_and_version)
end

def in_root_dir(&)
  chdir(Bundler.root, &)
end

def gemvault(*, **)
  sh "gemvault", *, **
end

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList["spec/**/*_spec.rb"]
end

RuboCop::RakeTask.new
CLOBBER.include "dist"

desc "Generate a new cop with a template"
task :new_cop, [:cop] do |_task, args|
  require "rubocop"

  cop_name = args.fetch(:cop) do
    warn "usage: bundle exec rake new_cop[Department/Name]"
    exit!
  end

  generator = RuboCop::Cop::Generator.new(cop_name)
  generator.write_source
  generator.write_spec
  generator.inject_require(root_file_path: "lib/rubocop/cop/kaizo_cops.rb")
  generator.inject_config(config_file_path: "config/default.yml")

  puts generator.todo
end

directory "dist" do
  mkdir "dist"
end

file "dist/vault.gemv" => "dist" do
  in_root_dir do
    gemvault "new", "dist/vault.gemv"
  end
end

ENV["gem_push"] = "0"
namespace :release do
  desc "release to a vault"
  task vault: ["dist/vault.gemv", :build] do
    FileList["pkg/*.gem"].each do |v|
      in_root_dir do
        gemvault "add", "dist/vault.gemv", v unless gemvault_contains? "dist/vault.gemv", v
      end
    end
  end
end

Rake::Task[:release].enhance ["release:vault"]

task default: [:spec, :rubocop]
