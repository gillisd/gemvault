require "gemvault/tarvault"

RSpec.describe "Gemvault::Tarvault#remove" do
  describe "#remove" do
    it "removes one specific version and returns 1" do
      tarvault_with(foo_gem) do |v|
        expect(v.remove(foo_reference)).to eq(1)
      end
    end

    it "removes all versions by name and returns the count" do
      tarvault_with(foo_gem, build_gem(name: "foo", version: "2.0.0")) do |v|
        expect(v.remove(Gemvault::GemReference::AnyVersion.new(name: "foo"))).to eq(2)
      end
    end

    it "returns 0 when nothing matches" do
      create_tarvault { |v| expect(v.remove(Gemvault::GemReference.parse("nope", version: "1.0.0"))).to eq(0) }
    end
  end
end
