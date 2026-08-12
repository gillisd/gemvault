require "gemvault"
require "gemvault/tarvault"
require "sqlite3"

RSpec.describe "vault format versioning" do
  let(:declared_format_version) { open_vault(&:format_version) }

  it "reports format_version 3 for a Tarvault" do
    current_tarvault
    expect(declared_format_version).to eq(3)
  end

  it "reports format_version 1 for a Dbvault" do
    legacy_dbvault
    expect(declared_format_version).to eq(1)
  end

  it "reports format_version 2 for a tarvault whose index is manifest.json" do
    legacy_tarvault
    expect(declared_format_version).to eq(2)
  end

  it "opens a format-2 tarvault read-only rather than refusing it" do
    legacy_tarvault
    expect(open_vault { |v| v.gem_entries.map(&:name) }).to contain_exactly("foo", "bar")
  end

  it "refuses a Tarvault whose declared version is newer than READABLE_FORMATS" do
    current_tarvault
    bump_tarvault_version(path: vault_path, version: 99)
    expect { open_vault { |v| v } }.to raise_error(Gemvault::Vault::UnsupportedVersionError)
  end

  it "refuses a Dbvault whose declared version is newer than READABLE_FORMATS" do
    legacy_dbvault
    SQLite3::Database.new(vault_path.to_s) { |db| db.execute("UPDATE metadata SET value='99' WHERE key='vault_version'") }
    expect { open_vault { |v| v } }.to raise_error(Gemvault::Vault::UnsupportedVersionError)
  end

  it "refuses an unrecognized container (neither SQLite nor tar)" do
    File.binwrite(vault_path, "this is not a vault, just bytes " * 20)
    expect { open_vault { |v| v } }.to raise_error(Gemvault::Vault::Error, /Unrecognized/)
  end

  def bump_tarvault_version(path:, version:)
    archive = Gemvault::Tarball.new(path)
    name = Gemvault::ManifestText::FILENAME
    bumped = archive.read(name).sub(/\Agemvault \d+/, "gemvault #{version}")
    gems = archive.entries.reject { |entry| entry.name == name }
    archive.write([Gemvault::ArchiveEntry.new(name:, bytes: bumped)] + gems)
  end
end
