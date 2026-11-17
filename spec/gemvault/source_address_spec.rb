require "gemvault/source_address"

RSpec.describe Gemvault::SourceAddress do
  describe ".vaulted?" do
    it "recognises an address on the vault host" do
      expect(described_class.vaulted?("https://gemvault.invalid/vendor/private.gemv/")).to be(true)
    end

    it "rejects an address on another host" do
      expect(described_class.vaulted?("https://rubygems.org/")).to be(false)
    end

    it "rejects the vault host without a vault path" do
      expect(described_class.vaulted?("https://gemvault.invalid/")).to be(false)
    end
  end

  describe ".for" do
    it "addresses a vault by its path" do
      expect(described_class.for("vendor/private.gemv").to_s).to eq("https://gemvault.invalid/vendor/private.gemv/")
    end
  end

  describe "#vault_path" do
    it "reads the vault's relative path out of the address" do
      address = described_class.new("https://gemvault.invalid/vendor/private.gemv/")
      expect(address.vault_path).to eq("vendor/private.gemv")
    end

    it "accepts an address without a trailing slash" do
      address = described_class.new("https://gemvault.invalid/private.gemv")
      expect(address.vault_path).to eq("private.gemv")
    end

    context "when the address is not on the vault host" do
      it "raises" do
        expect { described_class.new("https://rubygems.org/") }.to raise_error(ArgumentError, /rubygems\.org/)
      end
    end
  end
end
