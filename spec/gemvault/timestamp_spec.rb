require "gemvault/timestamp"

RSpec.describe Gemvault::Timestamp do
  describe ".now" do
    it "is in the vault's canonical notation" do
      expect(described_class.now).to match(described_class::CANONICAL)
    end

    it "carries no whitespace" do
      expect(described_class.now).not_to include(" ")
    end
  end

  describe ".canonical" do
    it "passes a canonical timestamp through unchanged" do
      expect(described_class.canonical("2026-08-12T16:05:55Z")).to eq("2026-08-12T16:05:55Z")
    end

    it "converts the notation legacy SQLite vaults stored" do
      expect(described_class.canonical("2000-01-01 00:00:00")).to eq("2000-01-01T00:00:00Z")
    end

    it "rejects a notation it does not recognize" do
      expect { described_class.canonical("last tuesday") }.to raise_error(Gemvault::Timestamp::Error)
    end

    it "rejects a value carrying trailing content" do
      expect { described_class.canonical("2026-08-12T16:05:55Z extra") }.to raise_error(Gemvault::Timestamp::Error)
    end

    it "names the offending value" do
      expect { described_class.canonical("nonsense") }.to raise_error(/nonsense/)
    end
  end
end
