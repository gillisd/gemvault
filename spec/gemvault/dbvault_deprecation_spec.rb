require "gemvault"
require "gemvault/dbvault"

RSpec.describe "deprecated SQLite (Dbvault) format" do
  it "warns when an existing SQLite vault is opened" do
    legacy_dbvault
    Gemvault::Vault.open(vault_path, &:size)
    expect(Gemvault::Deprecation.output.string).to include("gemvault upgrade")
  end

  it "still reads from an existing SQLite vault" do
    legacy_dbvault
    names = Gemvault::Vault.open(vault_path) { |v| v.gem_entries.map(&:name) }
    expect(names).to contain_exactly("foo", "bar")
  end

  it "refuses add on an existing SQLite vault" do
    legacy_dbvault
    gem = build_gem(name: "baz", version: "3.0.0")
    Gemvault::Vault.open(vault_path) do |v|
      expect { v.add(gem) }.to raise_error(Gemvault::Vault::ReadOnlyError, /upgrade/)
    end
  end

  it "refuses remove on an existing SQLite vault" do
    legacy_dbvault
    ref = Gemvault::GemReference.parse("foo", version: "1.0.0")
    Gemvault::Vault.open(vault_path) do |v|
      expect { v.remove(ref) }.to raise_error(Gemvault::Vault::ReadOnlyError)
    end
  end
end
