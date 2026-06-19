require "gemvault/bundler_installation"
require "gemvault/bundler_patch/outcome"
require "gemvault/bundler_patch/outcomes"

RSpec.describe Gemvault::BundlerPatch::Outcomes do
  let(:installation_a) { instance_double(Gemvault::BundlerInstallation) }
  let(:installation_b) { instance_double(Gemvault::BundlerInstallation) }
  let(:applied_a) { Gemvault::BundlerPatch::Outcome::Applied[installation: installation_a] }
  let(:applied_b) { Gemvault::BundlerPatch::Outcome::Applied[installation: installation_b] }
  let(:already_b) { Gemvault::BundlerPatch::Outcome::AlreadyApplied[installation: installation_b] }

  describe "#each" do
    it "yields each outcome in order" do
      outcomes = described_class.new([applied_a, already_b])
      expect(outcomes.to_a).to eq([applied_a, already_b])
    end
  end

  describe "Enumerable composition" do
    it "supports map" do
      outcomes = described_class.new([applied_a, applied_b])
      expect(outcomes.map(&:installation)).to eq([installation_a, installation_b])
    end

    it "supports count" do
      outcomes = described_class.new([applied_a, already_b])
      expect(outcomes.count).to eq(2)
    end
  end

  describe "#empty?" do
    it "is true when no outcomes" do
      expect(described_class.new([])).to be_empty
    end

    it "is false when outcomes are present" do
      expect(described_class.new([applied_a])).not_to be_empty
    end
  end

  describe "#summary" do
    it "is :no_installations when empty" do
      expect(described_class.new([]).summary).to eq(:no_installations)
    end

    it "returns the unique class when all outcomes share a class" do
      outcomes = described_class.new([applied_a, applied_b])
      expect(outcomes.summary).to eq(Gemvault::BundlerPatch::Outcome::Applied)
    end

    it "is :mixed when classes differ" do
      outcomes = described_class.new([applied_a, already_b])
      expect(outcomes.summary).to eq(:mixed)
    end
  end
end
