RSpec.describe "gemvault remove", :integration do
  it "removes via a combined NAME-VERSION argument", :aggregate_failures do
    output, status = run_remove(gems: [["foo", "1.0.0"]], remove_args: "foo-1.0.0")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("Removed 1 gem")
  end

  it "removes via a positional VERSION argument", :aggregate_failures do
    output, status = run_remove(gems: [["foo", "1.0.0"]], remove_args: "foo 1.0.0")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("Removed 1 gem")
  end

  it "removes via the --version option", :aggregate_failures do
    output, status = run_remove(gems: [["foo", "1.0.0"]], remove_args: "foo --version 1.0.0")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("Removed 1 gem")
  end

  it "removes via the -v short option", :aggregate_failures do
    output, status = run_remove(gems: [["foo", "1.0.0"]], remove_args: "foo -v 1.0.0")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("Removed 1 gem")
  end

  it "preserves hyphenated names in the combined form", :aggregate_failures do
    output, status = run_remove(gems: [["foo-bar", "2.3.4"]], remove_args: "foo-bar-2.3.4")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("Removed 1 gem")
  end

  it "lets --version override the embedded version in NAME-VERSION", :aggregate_failures do
    output, status = remove_with_version_override
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("Removed 1 gem")
    expect(output).to match(/^foo-1\.0\.0$/)
    expect(output).not_to match(/^foo-2\.0\.0$/)
  end

  it "rejects a ranged version requirement", :aggregate_failures do
    output, status = run_remove(gems: [["foo", "1.0.0"]], remove_args: "foo --version '~> 1.0'")
    expect(status).not_to be_success
    expect(output).to match(/exact version/i)
  end
end
