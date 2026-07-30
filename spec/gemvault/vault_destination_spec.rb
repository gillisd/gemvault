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

  describe "#exist?" do
    it "is false for a path nothing occupies" do
      expect(described_class.new(gem_dir / "absent").exist?).to be(false)
    end

    it "is true once the vault file is there" do
      (gem_dir / "there.gemv").write("")
      expect(described_class.new(gem_dir / "there.gemv").exist?).to be(true)
    end
  end

  describe "#create_parents" do
    it "answers nil when the parent directory already exists" do
      expect(described_class.new(gem_dir / "vault.gemv").create_parents).to be_nil
    end

    it "answers nil for a bare name in the working directory" do
      expect(described_class.new("vault.gemv").create_parents).to be_nil
    end

    it "creates a single missing parent" do
      described_class.new(gem_dir / "path/vault.gemv").create_parents
      expect(gem_dir / "path").to be_a_directory
    end

    it "creates every missing ancestor" do
      described_class.new(gem_dir / "path/to/deep/vault.gemv").create_parents
      expect(gem_dir / "path/to/deep").to be_a_directory
    end

    it "answers the shallowest directory it created" do
      created = described_class.new(gem_dir / "path/to/deep/vault.gemv").create_parents
      expect(created.to_s).to eq((gem_dir / "path").to_s)
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
