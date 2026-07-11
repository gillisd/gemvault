require "gemvault/deprecation"
require "stringio"

RSpec.describe Gemvault::Deprecation do
  let(:io) { StringIO.new }

  before do
    described_class.reset!
    described_class.output = io
  end

  describe ".warn_once" do
    it "writes the message once per unique text", :aggregate_failures do
      described_class.warn_once("legacy vault")
      described_class.warn_once("legacy vault")
      expect(io.string.scan("legacy vault").length).to eq(1)
      expect(io.string).to start_with("gemvault:")
    end

    it "warns separately for distinct messages" do
      described_class.warn_once("vault a")
      described_class.warn_once("vault b")
      expect(io.string.lines.length).to eq(2)
    end

    it "stays silent inside a silence block" do
      described_class.silence { described_class.warn_once("hushed") }
      expect(io.string).to be_empty
    end

    it "stays silent when the environment opts out" do
      allow(ENV).to receive(:key?).with(described_class::ENV_KEY).and_return(true)
      described_class.warn_once("suppressed")
      expect(io.string).to be_empty
    end
  end
end
