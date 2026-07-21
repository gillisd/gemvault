require "gemvault"
require "gemvault/tarvault"
require "sqlite3"
require "json"

RSpec.describe "vault format versioning" do
  it "reports format_version 2 for a Tarvault" do
    Gemvault::Vault.open(vault_path, create: true) { |v| v.add(build_gem(name: "foo", version: "1.0.0")) }
    Gemvault::Vault.open(vault_path) { |v| expect(v.format_version).to eq(2) }
  end

  it "reports format_version 1 for a Dbvault" do
    legacy_dbvault
    Gemvault::Vault.open(vault_path) { |v| expect(v.format_version).to eq(1) }
  end

  it "refuses a Tarvault whose declared version is newer than READABLE_FORMATS" do
    Gemvault::Vault.open(vault_path, create: true) { |v| v.add(build_gem(name: "foo", version: "1.0.0")) }
    bump_tarvault_version(path: vault_path, version: 99)
    expect { Gemvault::Vault.open(vault_path) { |v| v } }.to raise_error(Gemvault::Vault::UnsupportedVersionError)
  end

  it "refuses a Dbvault whose declared version is newer than READABLE_FORMATS" do
    legacy_dbvault
    SQLite3::Database.new(vault_path.to_s) { |db| db.execute("UPDATE metadata SET value='99' WHERE key='vault_version'") }
    expect { Gemvault::Vault.open(vault_path) { |v| v } }.to raise_error(Gemvault::Vault::UnsupportedVersionError)
  end

  it "refuses an unrecognized container (neither SQLite nor tar)" do
    File.binwrite(vault_path, "this is not a vault, just bytes " * 20)
    expect { Gemvault::Vault.open(vault_path) { |v| v } }.to raise_error(Gemvault::Vault::Error, /Unrecognized/)
  end

  def bump_tarvault_version(path:, version:)
    archive = Gemvault::Tarball.new(path)
    manifest = JSON.parse(archive.read("manifest.json"))
    manifest["vault_version"] = version
    gems = archive.entries.reject { |entry| entry.name == "manifest.json" }
    manifest_entry = Gemvault::ArchiveEntry.new(name: "manifest.json", bytes: JSON.generate(manifest))
    archive.write([manifest_entry] + gems)
  end
end
