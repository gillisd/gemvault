require_relative "lib/gemvault/version"

Gem::Specification.new do |spec|
  spec.name = "gemvault"
  spec.version = Gemvault::VERSION
  spec.authors = ["David Gillis"]
  spec.email = ["david@flipmine.com"]
  spec.summary = "Multi-gem portable archives backed by SQLite"
  spec.description = "SQLite-backed .gemv archives for bundling and distributing multiple gems as a single file"
  spec.homepage = "https://github.com/gillisd/gemvault"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.1"

  gemspec_file = File.basename(__FILE__)
  files = begin
    IO.popen(["git", "ls-files", "-z"], chdir: __dir__, err: IO::NULL) { |ls|
      ls.readlines("\x0", chomp: true).reject do |f|
        (f == gemspec_file) ||
          f.start_with?("bin/", "test/", "spec/", "features/", ".git", "shim/", "Gemfile") ||
          f == "plugins.rb"
      end
    }
  rescue Errno::ENOENT
    []
  end
  files = Dir.glob("{lib,exe}/**/*").push("README.md", "LICENSE.txt", "Rakefile") if files.empty?
  spec.files = files
  spec.bindir = "exe"
  spec.executables = ["gemvault"]
  spec.require_paths = ["lib"]

  spec.add_dependency "bundler", ">= 2.0"
  spec.add_dependency "command_kit", "~> 0.6"
  spec.add_dependency "sqlite3", "~> 2.0"

  spec.metadata = {
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/gillisd/gemvault",
    "bug_tracker_uri" => "https://github.com/gillisd/gemvault/issues",
    "changelog_uri" => "https://github.com/gillisd/gemvault/blob/master/CHANGELOG.md",
  }
end
