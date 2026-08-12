RSpec.describe "gemvault doctor when the reinstall cannot succeed", :integration do
  let(:outcome) { doctor_reinstall_failure_outcome }

  it "starts from a working bundle" do
    expect(outcome.doctored).to include("Bundle complete!")
  end

  it "leaves the plugin registered rather than stranding the machine" do
    expect(outcome.index).to include("bundler-source-vault")
  end

  it "says it restored the index, in one line" do
    expect(outcome.doctored).to include("restored the previous plugin index")
  end

  it "fails rather than pretending the repair happened" do
    expect(outcome.doctored).to include("doctor exit: 1")
  end

  it "recovers fully once the Gemfile is fixed", :aggregate_failures do
    expect(outcome.healed).to include("Bundle complete!")
    expect(outcome.healed).not_to include("restored the previous plugin index")
  end
end
