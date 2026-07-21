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
