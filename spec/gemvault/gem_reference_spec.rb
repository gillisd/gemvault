RSpec.describe "Gemvault::GemReference" do
  describe ".parse" do
    context "with a bare name and no explicit version" do
      it "returns an AnyVersion specification for that name"
    end

    context "with a bare name and an explicit exact version" do
      it "returns a SpecificVersion for that name and version"
    end

    context "with a combined NAME-VERSION input" do
      it "splits on the last hyphen when the trailing segment is a valid version"
      it "keeps all hyphens in the name when only the final segment is a version"
      it "treats the whole string as the name when no trailing version is present"
      it "treats the whole string as the name when the trailing segment is not a valid version"
    end

    context "with a combined NAME-VERSION input AND an explicit version" do
      it "takes the base name from the input and the version from the explicit argument"
    end

    context "with a ranged version requirement" do
      it "raises NonExactVersionError whose message names the offending requirement"
    end
  end
end
