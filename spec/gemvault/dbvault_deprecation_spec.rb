require "gemvault"
require "gemvault/dbvault"

RSpec.describe "deprecated SQLite (Dbvault) format" do
  def build_legacy_dbvault(name = "foo", version = "1.0.0")
    Gemvault::Dbvault.open(vault_path, create: true) { |v| v.add(build_gem(name, version)) }
  end

  it "warns when an existing SQLite vault is opened" do
    build_legacy_dbvault
    Gemvault::Vault.open(vault_path, &:size)
    expect(Gemvault::Deprecation.output.string).to include("gemvault upgrade")
  end

  it "still reads from an existing SQLite vault" do
    build_legacy_dbvault
    names = Gemvault::Vault.open(vault_path) { |v| v.gem_entries.map(&:name) }
    expect(names).to eq(["foo"])
  end

  it "refuses add on an existing SQLite vault" do
    build_legacy_dbvault
    Gemvault::Vault.open(vault_path) do |v|
      expect { v.add(build_gem("bar", "2.0.0")) }.to raise_error(Gemvault::Vault::ReadOnlyError, /upgrade/)
    end
  end

  it "refuses remove on an existing SQLite vault" do
    build_legacy_dbvault
    ref = Gemvault::GemReference.parse("foo", version: "1.0.0")
    Gemvault::Vault.open(vault_path) do |v|
      expect { v.remove(ref) }.to raise_error(Gemvault::Vault::ReadOnlyError)
    end
  end

  it "allows writing to a freshly created Dbvault (migration/legacy tooling)" do
    Gemvault::Dbvault.open(vault_path, create: true) do |v|
      expect { v.add(build_gem("foo", "1.0.0")) }.to change { v.size }.by(1)
    end
  end
end
