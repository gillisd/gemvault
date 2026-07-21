require "fileutils"

# Copies the committed legacy (format-1 SQLite) vault fixture into a writable
# temp path so specs can read, upgrade, or otherwise exercise it without
# mutating the checked-in fixture. The fixture holds foo-1.0.0 and bar-2.0.0,
# each with created_at "2000-01-01 00:00:00".
module LegacyDbvault
  FIXTURE = File.expand_path("../fixtures/legacy-v1.gemv", __dir__).freeze

  def legacy_dbvault
    FileUtils.cp(FIXTURE, vault_path)
    vault_path
  end
end

RSpec.configure do |config|
  config.include LegacyDbvault
end
