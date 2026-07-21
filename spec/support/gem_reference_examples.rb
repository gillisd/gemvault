RSpec.shared_examples "a gem reference" do
  it "matches a gem entry it selects" do
    expect(reference.matches?(matching_entry)).to be(true)
  end

  it "rejects a gem entry it does not select" do
    expect(reference.matches?(nonmatching_entry)).to be(false)
  end
end
