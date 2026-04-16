require "rspec/autorun"
require "open3"
require "pathname"
require "tmpdir"
require "fileutils"
require "rubygems/package"

GEM_SOURCE = Pathname("/gem")
BUILD_DIR = Pathname("/tmp/build")

module ContainerTestHelper
  def install_gemvault!
    if Gem::Specification.find_all_by_name("gemvault").any?
      @system_gem_path = Gem.path.join(File::PATH_SEPARATOR)
      return
    end

    BUILD_DIR.mkpath
    FileUtils.cp_r("#{GEM_SOURCE}/.", BUILD_DIR)

    run_cmd!("gem", "build", "gemvault.gemspec", chdir: BUILD_DIR)
    gem_file = BUILD_DIR.glob("gemvault-*.gem").first
    run_cmd!("gem", "install", "--no-document", gem_file.to_s)

    run_cmd!("gem", "build", "bundler-source-vault.gemspec", chdir: BUILD_DIR / "shim")
    shim_file = (BUILD_DIR / "shim").glob("bundler-source-vault-*.gem").first
    run_cmd!("gem", "install", "--no-document", shim_file.to_s)

    Gem.clear_paths
    @system_gem_path = Gem.path.join(File::PATH_SEPARATOR)
  end

  def gem_env_for(gem_home)
    {
      "GEM_HOME" => gem_home.to_s,
      "GEM_PATH" => [gem_home.to_s, @system_gem_path].join(File::PATH_SEPARATOR),
    }
  end

  def build_gem(name, version, dir:, platform: nil, files: nil, dependencies: [])
    dir = Pathname(dir)
    files ||= {"lib/#{name}.rb" => "module #{name.split("-").map(&:capitalize).join}; end"}

    spec = Gem::Specification.new do |s|
      s.name = name
      s.version = version
      s.summary = "Test gem"
      s.authors = ["Test"]
      s.homepage = "https://example.com"
      s.license = "MIT"
      s.platform = platform if platform
      files.each_key { |f| s.files << f }
      dependencies.each { |dep, req| s.add_dependency(dep, req) }
    end

    files.each do |path, content|
      full = dir / path
      full.dirname.mkpath
      full.write(content)
    end

    gem_file = Dir.chdir(dir) { Gem::Package.build(spec, true) }
    dir / gem_file
  end

  def create_vault(path, *gem_paths)
    require "gemvault"
    vault = Gemvault::Vault.new(path, create: true)
    gem_paths.each { |gp| vault.add(gp) }
    vault.close
    Pathname(path)
  end

  def run_bundle(*args, chdir:, env: {})
    Open3.capture2e(env, "bundle", *args, chdir: chdir.to_s)
  end

  def run_bundle!(*args, chdir:, env: {})
    output, status = run_bundle(*args, chdir: chdir, env: env)
    raise "bundle #{args.join(" ")} failed:\n#{output}" unless status.success?
    [output, status]
  end

  private

  def run_cmd!(*cmd, chdir: nil)
    opts = {}
    opts[:chdir] = chdir.to_s if chdir
    output, status = Open3.capture2e(*cmd, **opts)
    raise "Command failed: #{cmd.join(" ")}\n#{output}" unless status.success?
    output
  end
end

RSpec.configure do |config|
  config.include ContainerTestHelper
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.define_derived_metadata do |meta|
    meta[:aggregate_failures] = true unless meta.key?(:aggregate_failures)
  end
end
