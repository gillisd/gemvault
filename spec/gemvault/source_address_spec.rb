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

    it "recognises an address given as a URI" do
      expect(described_class.vaulted?(Gem::URI("https://gemvault.invalid/private.gemv/"))).to be(true)
    end

    it "recognises a vault path that climbs out of the Gemfile's directory" do
      expect(described_class.vaulted?("https://gemvault.invalid/../shared/private.gemv/")).to be(true)
    end

    it "rejects an absolute vault path" do
      expect(described_class.vaulted?("https://gemvault.invalid//etc/private.gemv/")).to be(false)
    end

    it "rejects an address with a query" do
      expect(described_class.vaulted?("https://gemvault.invalid/private.gemv/?a=1")).to be(false)
    end

    it "rejects an address with a fragment" do
      expect(described_class.vaulted?("https://gemvault.invalid/private.gemv/#top")).to be(false)
    end

    it "rejects an address that is not https" do
      expect(described_class.vaulted?("http://gemvault.invalid/private.gemv/")).to be(false)
    end

    it "rejects a host that only starts with the vault host" do
      expect(described_class.vaulted?("https://gemvault.invalid.example.com/private.gemv/")).to be(false)
    end

    it "rejects the vault host with a port" do
      expect(described_class.vaulted?("https://gemvault.invalid:8443/private.gemv/")).to be(false)
    end
  end

  describe "#to_s" do
    it "ends the address with a slash" do
      expect(described_class.new("https://gemvault.invalid/private.gemv").to_s)
        .to eq("https://gemvault.invalid/private.gemv/")
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

    context "when the vault path is absolute" do
      it "raises" do
        expect { described_class.new("https://gemvault.invalid//etc/private.gemv/") }.to raise_error(ArgumentError)
      end
    end

    context "when the address is not on the vault host" do
      it "raises" do
        expect { described_class.new("https://rubygems.org/") }.to raise_error(ArgumentError, /rubygems\.org/)
      end
    end
  end
end
