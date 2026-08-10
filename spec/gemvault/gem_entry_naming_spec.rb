require "gemvault/gem_entry"

RSpec.describe "Gemvault::GemEntry naming" do
  subject(:entry) { Gemvault::GemEntry.new(name: "foo", version: "1.0.0", **attributes) }

  let(:attributes) { {} }

  context "with the default ruby platform" do
    it "joins name and version into the full name" do
      expect(entry.full_name).to eq("foo-1.0.0")
    end

    it "suffixes .gem onto the full name for the filename" do
      expect(entry.filename).to eq("foo-1.0.0.gem")
    end

    it "reads as name-version" do
      expect(entry.to_s).to eq("foo-1.0.0")
    end
  end

  context "with a native platform" do
    let(:attributes) { { platform: "x86_64-linux" } }

    it "appends the platform to the full name" do
      expect(entry.full_name).to eq("foo-1.0.0-x86_64-linux")
    end

    it "parenthesizes the platform in to_s" do
      expect(entry.to_s).to eq("foo-1.0.0 (x86_64-linux)")
    end
  end
end
