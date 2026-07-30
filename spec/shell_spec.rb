RSpec.describe Shell do
  subject(:shell) { described_class.new }

  describe "#run" do
    it "is true when the command succeeds" do
      expect(shell.run("true")).to be(true)
    end

    it "is false when the command fails" do
      expect(shell.run("false")).to be(false)
    end

    it "is false when the command does not exist" do
      expect(shell.run("gemvault-no-such-command")).to be(false)
    end

    it "runs the command without a shell" do
      expect(shell.run("test", "1", "=", "1")).to be(true)
    end
  end

  describe "#capture" do
    it "returns the command's standard output" do
      expect(shell.capture("echo", "hello")).to eq("hello\n")
    end

    it "returns empty output as an empty string" do
      expect(shell.capture("true")).to eq("")
    end
  end
end
