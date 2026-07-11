require_relative "../../test/support/gem_factory"
require "tmpdir"
require "fileutils"

module GemFixtures
  def gem_dir
    @gem_dir ||= Pathname(Dir.mktmpdir("gemvault_spec"))
  end

  def build_gem(name, version, **options)
    GemFactory.new(name, version, dir: gem_dir, **options).build
  end

  def vault_path
    @vault_path ||= gem_dir / "test.gemv"
  end

  def corrupt_gem_blob(path)
    data = File.binread(path)
    idx = data.bytesize / 2
    data.setbyte(idx, data.getbyte(idx) ^ 0xFF)
    File.binwrite(path, data)
  end
end

RSpec.configure do |config|
  config.include GemFixtures
  config.after { FileUtils.rm_rf(@gem_dir) if @gem_dir }
end
