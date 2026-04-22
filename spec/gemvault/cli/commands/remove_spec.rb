require "gemvault/cli/commands/remove"
require "gemvault/vault"

RSpec.describe Gemvault::CLI::Commands::Remove do
  describe "#run" do
    context "with a NAME only" do
      it "calls Vault#remove with the name and no version"
      it "prints the removal count to stdout"
      it "exits 1 and writes to stderr when the vault has no matching gem"
    end

    context "with a positional VERSION argument" do
      it "calls Vault#remove with the name and that exact version string"
    end

    context "with a combined NAME-VERSION argument" do
      it "splits on the last hyphen when the trailing segment is a valid version"
      it "keeps hyphens in the name when only the final segment is a version"
      it "treats the whole string as a name when no trailing version is present"
      it "treats the whole string as a name when the trailing segment is not a valid version"
    end

    context "with the --version option" do
      it "calls Vault#remove with the name and that exact version string"
    end

    context "with the -v short option" do
      it "calls Vault#remove with the name and that exact version string"
    end

    context "with multiple version sources supplied" do
      it "lets --version override a positional VERSION argument"
      it "lets --version override a combined NAME-VERSION argument"
      it "lets a positional VERSION argument override a combined NAME-VERSION argument"
    end

    context "with a non-exact version requirement" do
      it "exits 1 without calling Vault#remove and names the offending requirement in stderr"
    end
  end
end
