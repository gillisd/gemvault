require "gemvault/bundler_gemfile"

RSpec.describe Gemvault::BundlerGemfile do
  describe "#path" do
    it "finds a Gemfile in the directory itself" do
      (gem_dir / "Gemfile").write("")
      expect(described_class.new(dir: gem_dir, env: {}).path).to eq(gem_dir / "Gemfile")
    end

    it "prefers gems.rb over Gemfile in the same directory" do
      (gem_dir / "Gemfile").write("")
      (gem_dir / "gems.rb").write("")
      expect(described_class.new(dir: gem_dir, env: {}).path).to eq(gem_dir / "gems.rb")
    end

    it "walks up to an ancestor" do
      (gem_dir / "Gemfile").write("")
      (gem_dir / "nested/deeper").mkpath
      expect(described_class.new(dir: gem_dir / "nested/deeper", env: {}).path).to eq(gem_dir / "Gemfile")
    end

    it "prefers the nearest ancestor" do
      (gem_dir / "Gemfile").write("")
      (gem_dir / "nested").mkpath
      (gem_dir / "nested/Gemfile").write("")
      expect(described_class.new(dir: gem_dir / "nested", env: {}).path).to eq(gem_dir / "nested/Gemfile")
    end

    it "is nil when no ancestor holds one" do
      expect(described_class.new(dir: "/", env: {}).path).to be_nil
    end

    context "when BUNDLE_GEMFILE names an existing file" do
      it "wins over the search" do
        (gem_dir / "Gemfile").write("")
        (gem_dir / "elsewhere.rb").write("")
        gemfile = described_class.new(dir: gem_dir, env: { "BUNDLE_GEMFILE" => (gem_dir / "elsewhere.rb").to_s })
        expect(gemfile.path).to eq(gem_dir / "elsewhere.rb")
      end

      it "resolves a relative value against the directory" do
        (gem_dir / "relative.rb").write("")
        gemfile = described_class.new(dir: gem_dir, env: { "BUNDLE_GEMFILE" => "relative.rb" })
        expect(gemfile.path).to eq(gem_dir / "relative.rb")
      end
    end

    context "when BUNDLE_GEMFILE names a file that is not there" do
      it "is nil rather than the missing path" do
        gemfile = described_class.new(dir: "/", env: { "BUNDLE_GEMFILE" => "Gemfile" })
        expect(gemfile.path).to be_nil
      end

      it "does not mask a Gemfile the search would find" do
        (gem_dir / "Gemfile").write("")
        gemfile = described_class.new(dir: gem_dir, env: { "BUNDLE_GEMFILE" => "absent.rb" })
        expect(gemfile.path).to eq(gem_dir / "Gemfile")
      end
    end

    context "when BUNDLE_GEMFILE is empty" do
      it "falls back to the search" do
        (gem_dir / "Gemfile").write("")
        gemfile = described_class.new(dir: gem_dir, env: { "BUNDLE_GEMFILE" => "" })
        expect(gemfile.path).to eq(gem_dir / "Gemfile")
      end
    end
  end

  describe "#exist?" do
    it "is true when a Gemfile was found" do
      (gem_dir / "Gemfile").write("")
      expect(described_class.new(dir: gem_dir, env: {}).exist?).to be(true)
    end

    it "is false when none was" do
      expect(described_class.new(dir: "/", env: {}).exist?).to be(false)
    end
  end
end
