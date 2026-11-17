require "gemvault/shelf"

RSpec.describe Gemvault::Shelf do
  include GemFixtures

  subject(:shelf) { described_class.new(directory) }

  let(:directory) { gem_dir / "shelf" }

  def publish_into(index) = open_vault { |vault| index.publish(vault) }

  describe "#addressable?" do
    it "is true for a directory a gem source address can carry" do
      expect(shelf).to be_addressable
    end

    context "when the directory name is percent-encoded" do
      let(:directory) { gem_dir / "vendor%2Ftest.gemv" }

      it "is true" do
        expect(shelf).to be_addressable
      end
    end

    context "when the directory holds a space" do
      let(:directory) { gem_dir / "My Projects" / "shelf" }

      it "is false" do
        expect(shelf).not_to be_addressable
      end
    end

    context "when the directory holds a character outside ASCII" do
      let(:directory) { gem_dir / "josé" / "shelf" }

      it "is false" do
        expect(shelf).not_to be_addressable
      end
    end

    context "when the directory holds a character that ends an address path" do
      let(:directory) { gem_dir / "app#1" / "shelf" }

      it "is false" do
        expect(shelf).not_to be_addressable
      end
    end
  end

  describe "#writable?" do
    it "is true when the directory can be created" do
      expect(shelf).to be_writable
    end

    context "when the nearest existing directory is read-only", :unprivileged do
      let(:directory) { gem_dir / "locked" / "deep" / "shelf" }

      before do
        (gem_dir / "locked").mkpath
        (gem_dir / "locked").chmod(0o555)
      end

      after { (gem_dir / "locked").chmod(0o755) }

      it "is false" do
        expect(shelf).not_to be_writable
      end
    end
  end

  describe "#usable?" do
    it "is true for an addressable directory that can be created" do
      expect(shelf).to be_usable
    end

    context "when the directory cannot be addressed" do
      let(:directory) { gem_dir / "My Projects" / "shelf" }

      it "is false" do
        expect(shelf).not_to be_usable
      end
    end
  end

  describe "#index_for" do
    it "is the index in the stamp's directory" do
      expect(shelf.index_for("1-2-3").directory).to eq("#{directory}/1-2-3")
    end

    it "refuses a stamp that is not one" do
      expect { shelf.index_for("../x") }.to raise_error(ArgumentError)
    end
  end

  describe "#stock" do
    before { current_tarvault }

    it "publishes the index for the stamp" do
      expect(shelf.stock("1-2-3") { |index| publish_into(index) }).to be_published
    end

    it "publishes into the stamp's directory" do
      shelf.stock("1-2-3") { |index| publish_into(index) }
      expect(directory / "1-2-3" / "gems" / "foo-1.0.0.gem").to exist
    end

    it "does not publish again once published" do
      shelf.stock("1-2-3") { |index| publish_into(index) }
      expect { shelf.stock("1-2-3") { raise "published twice" } }.not_to raise_error
    end

    context "when a publish was cut short" do
      before do
        (directory / "1-2-3.partial" / "gems").mkpath
        (directory / "1-2-3.partial" / "gems" / "junk.gem").write("")
        shelf.stock("1-2-3") { |index| publish_into(index) }
      end

      it "publishes afresh" do
        expect(directory / "1-2-3" / "gems" / "junk.gem").not_to exist
      end

      it "leaves no partial index" do
        expect(directory / "1-2-3.partial").not_to exist
      end
    end

    context "when the stamp's directory lacks the released listing" do
      before { (directory / "1-2-3" / "gems").mkpath }

      it "publishes" do
        expect(shelf.stock("1-2-3") { |index| publish_into(index) }).to be_published
      end
    end

    context "when the shelf holds an index for another stamp" do
      before do
        shelf.stock("1-2-3") { |index| publish_into(index) }
        (directory / "keep.txt").write("")
        shelf.stock("4-5-6") { |index| publish_into(index) }
      end

      it "removes the superseded index" do
        expect(directory / "1-2-3").not_to exist
      end

      it "keeps entries that are not indexes" do
        expect(directory / "keep.txt").to exist
      end
    end

    context "when the directory name holds a glob character" do
      let(:directory) { gem_dir / "app*" / "shelf" }
      let(:neighbour) { gem_dir / "apple" / "shelf" / "9-9-9" }

      before do
        neighbour.mkpath
        shelf.stock("1-2-3") { |index| publish_into(index) }
      end

      it "leaves a matching neighbour's index alone" do
        expect(neighbour).to exist
      end
    end

    context "when two callers stock the same stamp while the shelf is locked" do
      let(:publishes) { Queue.new }
      let(:lock) { (directory / ".lock").open(File::RDWR | File::CREAT) }
      let(:callers) { Array.new(2) { Thread.new { stock_recording } } }

      def stock_recording
        described_class.new(directory).stock("1-2-3") do |index|
          publishes << index
          publish_into(index)
        end
      end

      def release
        lock.flock(File::LOCK_UN)
        callers.each(&:join)
      end

      before do
        directory.mkpath
        lock.flock(File::LOCK_EX)
        Thread.pass until callers.all?(&:stop?)
      end

      after { lock.close }

      it "publishes nothing until the lock is released" do
        waiting = publishes.size
        release
        expect(waiting).to eq(0)
      end

      it "publishes once after the lock is released" do
        release
        expect(publishes.size).to eq(1)
      end
    end
  end
end
