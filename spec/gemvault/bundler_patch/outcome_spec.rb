require "gemvault/bundler_installation"
require "gemvault/bundler_patch/outcome"

RSpec.describe Gemvault::BundlerPatch::Outcome do
  let(:installation) { instance_double(Gemvault::BundlerInstallation) }

  shared_examples "an outcome variant" do
    subject(:outcome) { described_class[installation: installation] }

    it "exposes the installation" do
      expect(outcome.installation).to eq(installation)
    end

    it "equals another instance with the same installation" do
      expect(outcome).to eq(described_class[installation: installation])
    end

    it "is an instance of itself" do
      expect(outcome).to be_a(described_class)
    end
  end

  describe Gemvault::BundlerPatch::Outcome::Applied do
    it_behaves_like "an outcome variant"
  end

  describe Gemvault::BundlerPatch::Outcome::AlreadyApplied do
    it_behaves_like "an outcome variant"
  end

  describe Gemvault::BundlerPatch::Outcome::Reverted do
    it_behaves_like "an outcome variant"
  end

  describe Gemvault::BundlerPatch::Outcome::NotApplied do
    it_behaves_like "an outcome variant"
  end

  describe "type distinctness" do
    it "distinguishes Applied from AlreadyApplied" do
      applied = Gemvault::BundlerPatch::Outcome::Applied[installation: installation]
      already = Gemvault::BundlerPatch::Outcome::AlreadyApplied[installation: installation]
      expect(applied).not_to eq(already)
    end

    it "distinguishes Reverted from NotApplied" do
      reverted    = Gemvault::BundlerPatch::Outcome::Reverted[installation: installation]
      not_applied = Gemvault::BundlerPatch::Outcome::NotApplied[installation: installation]
      expect(reverted).not_to eq(not_applied)
    end
  end
end
