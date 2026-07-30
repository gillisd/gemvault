RSpec.describe "gemvault doctor in a project whose Gemfile is inline", :integration do
  it "succeeds" do
    output, status = run_doctor_after_inline
    expect(status).to be_success, "Failed:\n#{output}"
  end

  it "does not report the plugin as missing" do
    output, = run_doctor_after_inline
    expect(output).not_to include("is not installed")
  end

  it "uninstalls the plugin it found" do
    output, = run_doctor_after_inline
    expect(output).to include("Uninstalled plugin bundler-source-vault")
  end

  it "does not fail on a Gemfile that was never on disk" do
    output, = run_doctor_after_inline
    expect(output).not_to include("Could not locate Gemfile")
  end

  it "does not dump bundler's usage screen" do
    output, = run_doctor_after_inline
    expect(output).not_to include("bundle binstubs GEM")
  end

  it "says why it is not reinstalling" do
    output, = run_doctor_after_inline
    expect(output).to match(/inline/i)
  end

  it "empties the project-local plugin index", :aggregate_failures do
    output, status = run_doctor_after_inline(followup: "grep -c bundler-source-vault $WORKDIR/.bundle/plugin/index")
    expect(status).not_to be_success
    expect(output).to match(/^0$/)
  end

  it "leaves the inline script working afterwards", :aggregate_failures do
    output, status = run_doctor_after_inline(followup: "ruby $WORKDIR/inline_test.rb")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output.scan(/^1\.0\.0$/).size).to eq(2)
  end
end
