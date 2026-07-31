require_relative "../../test/support/gem_factory"
require "tmpdir"
require "fileutils"

module GemFixtures
  TMP_ROOT = Pathname(__dir__).parent.parent.join("tmp").freeze

  def gem_dir
    @gem_dir ||= Pathname(Dir.mktmpdir("gemvault_spec", TMP_ROOT.tap(&:mkpath).to_s))
  end

  def build_gem(name:, version:, **options)
    GemFactory.new(name: name, version: version, dir: gem_dir, **options).build
  end

  def vault_path
    @vault_path ||= gem_dir / "test.gemv"
  end

  def current_tarvault(name: "foo", version: "1.0.0")
    Gemvault::Vault.open(vault_path, create: true) { |vault| vault.add(build_gem(name: name, version: version)) }
    vault_path
  end

  def open_vault(&) = Gemvault::Vault.open(vault_path, &)

  def create_tarvault(&) = Gemvault::Tarvault.open(vault_path, create: true, &)

  def reopen_tarvault(&) = Gemvault::Tarvault.open(vault_path, &)

  def tarvault_with(*gem_files)
    create_tarvault do |vault|
      gem_files.each { |gem_file| vault.add(gem_file) }
      yield vault if block_given?
    end
  end

  def foo_gem
    @foo_gem ||= build_gem(name: "foo", version: "1.0.0")
  end

  def foo_entry = Gemvault::GemEntry.new(name: "foo", version: "1.0.0")

  def foo_reference = Gemvault::GemReference.parse("foo", version: "1.0.0")

  def first_tar_entry_name(path)
    first = nil
    Gem::Package::TarReader.new(File.open(path, "rb")) { |r| r.each_entry { |e| first ||= e.full_name } }
    first
  end

  def corrupt_gem_blob(path)
    bytes = File.binread(path)
    middle = bytes.bytesize / 2
    bytes.setbyte(middle, bytes.getbyte(middle) ^ 0xFF)
    File.binwrite(path, bytes)
  end
end

RSpec.configure do |config|
  config.include GemFixtures
  config.after { FileUtils.rm_rf(@gem_dir) if @gem_dir }
end
