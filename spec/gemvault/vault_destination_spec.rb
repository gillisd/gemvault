require "gemvault/vault_destination"

RSpec.describe Gemvault::VaultDestination do
  describe "#path" do
    it "keeps a name that already carries the suffix" do
      expect(described_class.new("vault.gemv").path.to_s).to eq("vault.gemv")
    end

    it "appends the suffix to a bare name" do
      expect(described_class.new("vault").path.to_s).to eq("vault.gemv")
    end

    it "appends the suffix to a nested bare name" do
      expect(described_class.new("path/to/vault").path.to_s).to eq("path/to/vault.gemv")
    end

    it "leaves a nested name that carries the suffix alone" do
      expect(described_class.new("path/to/vault.gemv").path.to_s).to eq("path/to/vault.gemv")
    end
  end

  describe "#refuse_existing" do
    it "passes a path nothing occupies" do
      destination = described_class.new(gem_dir / "absent.gemv")
      expect { destination.refuse_existing }.not_to raise_error
    end

    context "when something occupies the path" do
      before { (gem_dir / "taken.gemv").write("") }

      it "raises" do
        destination = described_class.new(gem_dir / "taken.gemv")
        expect { destination.refuse_existing }.to raise_error(Gemvault::VaultDestination::Error, /already exists/)
      end

      it "names the occupied path" do
        destination = described_class.new(gem_dir / "taken.gemv")
        expect { destination.refuse_existing }.to raise_error(/taken/)
      end
    end
  end

  describe "#missing_directory" do
    it "is nil when the parent directory exists" do
      expect(described_class.new(gem_dir / "vault.gemv").missing_directory).to be_nil
    end

    it "is nil for a bare name in the working directory" do
      expect(described_class.new("vault.gemv").missing_directory).to be_nil
    end

    it "is the parent when only the parent is missing" do
      missing = described_class.new(gem_dir / "path/vault.gemv").missing_directory
      expect(missing.to_s).to eq((gem_dir / "path").to_s)
    end

    it "is the shallowest missing ancestor" do
      missing = described_class.new(gem_dir / "path/to/deep/vault.gemv").missing_directory
      expect(missing.to_s).to eq((gem_dir / "path").to_s)
    end
  end

  describe "#create_parents" do
    it "creates a single missing parent" do
      described_class.new(gem_dir / "path/vault.gemv").create_parents
      expect(gem_dir / "path").to be_a_directory
    end

    it "creates every missing ancestor" do
      described_class.new(gem_dir / "path/to/deep/vault.gemv").create_parents
      expect(gem_dir / "path/to/deep").to be_a_directory
    end

    it "does not create the vault file itself" do
      described_class.new(gem_dir / "path/vault.gemv").create_parents
      expect(gem_dir / "path/vault.gemv").not_to exist
    end

    context "when a parent is an existing file" do
      before { (gem_dir / "blocked").write("") }

      it "raises rather than letting mkpath fail" do
        destination = described_class.new(gem_dir / "blocked/vault.gemv")
        expect { destination.create_parents }.to raise_error(Gemvault::VaultDestination::Error)
      end

      it "names the offending path" do
        destination = described_class.new(gem_dir / "blocked/vault.gemv")
        expect { destination.create_parents }.to raise_error(/blocked/)
      end
    end

    context "when the directory cannot be created" do
      before do
        (gem_dir / "readonly").mkpath
        (gem_dir / "readonly").chmod(0o500)
      end

      after { (gem_dir / "readonly").chmod(0o700) }

      it "raises instead of surfacing the system error" do
        destination = described_class.new(gem_dir / "readonly/path/vault.gemv")
        expect { destination.create_parents }.to raise_error(Gemvault::VaultDestination::Error)
      end
    end
  end
end
