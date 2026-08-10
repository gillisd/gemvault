RSpec.describe "gemvault new", :integration do
  it "creates a vault whose parent directories do not exist yet", :aggregate_failures do
    output, status = run_new_then("path/to/gemvault.gemv", followup: "gemvault list path/to/gemvault.gemv")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("Created path/to/gemvault.gemv")
  end

  it "reports the directory it created" do
    output, = run_new("path/to/gemvault.gemv")
    expect(output).to include("Created directory path")
  end

  it "never reports a missing directory as a ruby exception", :aggregate_failures do
    output, = run_new("path/to/gemvault.gemv")
    expect(output).not_to include("Errno::ENOENT")
    expect(output).not_to include("tempfile.rb")
  end

  it "still creates a vault in the working directory" do
    output, status = run_new_then("plain.gemv", followup: "test -f plain.gemv")
    expect(status).to be_success, "Failed:\n#{output}"
  end

  it "still appends .gemv to a nested name without the suffix" do
    output, status = run_new_then("path/to/nosuffix", followup: "test -f path/to/nosuffix.gemv")
    expect(status).to be_success, "Failed:\n#{output}"
  end

  it "still refuses a vault that already exists", :aggregate_failures do
    output, status = run_new("path/to/twice.gemv && gemvault new path/to/twice.gemv")
    expect(status).not_to be_success
    expect(output).to include("already exists")
  end

  context "when a parent of the vault is a file" do
    it "fails", :aggregate_failures do
      output, status = run_new("blocked && gemvault new blocked.gemv/inner.gemv")
      expect(status).not_to be_success
      expect(output).to include("not a directory")
    end

    it "reports no ruby exception", :aggregate_failures do
      output, = run_new("blocked && gemvault new blocked.gemv/inner.gemv")
      expect(output).not_to include("Errno")
      expect(output).not_to match(/^\s+from /)
    end

    it "names the offending path" do
      output, = run_new("blocked && gemvault new blocked.gemv/inner.gemv")
      expect(output).to include("blocked.gemv")
    end
  end
end
