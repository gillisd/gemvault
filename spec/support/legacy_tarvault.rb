require "fileutils"

# Copies the committed format-2 vault fixture (a tarball whose index is the
# manifest.json gemvault wrote through 0.2.x) into a writable temp path. The
# fixture holds foo-1.0.0 and bar-2.0.0, each stored at "2000-01-01 00:00:00".
module LegacyTarvaultFixture
  FIXTURE = File.expand_path("../fixtures/legacy-v2.gemv", __dir__).freeze

  def legacy_tarvault
    FileUtils.cp(FIXTURE, vault_path)
    vault_path
  end
end

RSpec.configure do |config|
  config.include LegacyTarvaultFixture
end
