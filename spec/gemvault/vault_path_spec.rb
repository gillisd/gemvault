RSpec.describe Gemvault::VaultPath do
  describe ".resolve" do
    it "returns a plain path unchanged" do
      expect(described_class.resolve("vendor/vault.gemv")).to eq("vendor/vault.gemv")
    end

    it "strips a vault:// scheme from an absolute locator" do
      expect(described_class.resolve("vault:///home/user/vault.gemv")).to eq("/home/user/vault.gemv")
    end

    it "strips a file:// scheme from an absolute locator" do
      expect(described_class.resolve("file:///home/user/vault.gemv")).to eq("/home/user/vault.gemv")
    end

    it "treats the host of a two-slash relative locator as the leading path segment" do
      expect(described_class.resolve("file://vault.gemv")).to eq("vault.gemv")
    end

    it "returns locators with other schemes unchanged" do
      expect(described_class.resolve("https://example.com/vault.gemv")).to eq("https://example.com/vault.gemv")
    end

    it "returns unparseable locators unchanged" do
      expect(described_class.resolve("vault name with spaces.gemv")).to eq("vault name with spaces.gemv")
    end
  end
end
