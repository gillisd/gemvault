require "stringio"

require "gemvault/cli/destination"
require "gemvault/vault_destination"

RSpec.describe Gemvault::CLI::Destination do
  subject(:destination) { described_class.new(Gemvault::VaultDestination.new(path), stdout: stdout) }

  let(:stdout) { StringIO.new }

  describe "#path" do
    let(:path) { gem_dir / "vault" }

    it "answers the destination's path" do
      expect(destination.path.to_s).to eq((gem_dir / "vault.gemv").to_s)
    end
  end

  describe "#refuse_existing" do
    let(:path) { gem_dir / "vault.gemv" }

    it "passes a path nothing occupies" do
      expect { destination.refuse_existing }.not_to raise_error
    end

    it "raises for an occupied path" do
      path.write("")
      expect { destination.refuse_existing }.to raise_error(Gemvault::VaultDestination::Error)
    end
  end

  describe "#create_parents" do
    let(:path) { gem_dir / "path/to/vault.gemv" }

    it "creates the missing directories" do
      destination.create_parents
      expect(gem_dir / "path/to").to be_a_directory
    end

    it "announces the shallowest directory it created" do
      destination.create_parents
      expect(stdout.string).to eq("Created directory #{gem_dir / "path"}\n")
    end

    context "when the parent directory already exists" do
      let(:path) { gem_dir / "vault.gemv" }

      it "announces nothing" do
        destination.create_parents
        expect(stdout.string).to be_empty
      end
    end
  end
end
