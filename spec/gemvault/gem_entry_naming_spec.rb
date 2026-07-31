require "gemvault/gem_entry"

RSpec.describe "Gemvault::GemEntry naming" do
  def entry(**overrides) = Gemvault::GemEntry.new(name: "foo", version: "1.0.0", **overrides)

  describe "#full_name" do
    it "joins name and version for a ruby-platform gem" do
      expect(entry.full_name).to eq("foo-1.0.0")
    end

    it "appends the platform for a native gem" do
      expect(entry(platform: "x86_64-linux").full_name).to eq("foo-1.0.0-x86_64-linux")
    end
  end

  describe "#filename" do
    it "is the full name with a .gem suffix" do
      expect(entry.filename).to eq("foo-1.0.0.gem")
    end
  end

  describe "#to_s" do
    it "reads as name-version for a ruby-platform gem" do
      expect(entry.to_s).to eq("foo-1.0.0")
    end

    it "parenthesizes the platform for a native gem" do
      native = entry(platform: "linux")
      expect(native.to_s).to eq("foo-1.0.0 (linux)")
    end
  end
end
