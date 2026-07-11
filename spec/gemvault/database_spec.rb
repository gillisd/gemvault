RSpec.describe Gemvault::Database do
  let(:tmpdir) { Dir.mktmpdir("gemvault_db") }
  let(:path) { File.join(tmpdir, "test.db") }

  subject(:db) { described_class.connect(path) }

  after do
    db.disconnect
    FileUtils.rm_rf(tmpdir)
  end

  describe ".connect" do
    it "creates and queries a table" do
      db.run("CREATE TABLE items (name TEXT NOT NULL)")
      db[:items].insert(name: "foo")
      expect(db[:items].count).to eq(1)
    end

    it "round-trips binary blob data byte-for-byte" do
      db.run("CREATE TABLE blobs (data BLOB NOT NULL)")
      bytes = (0..255).map(&:chr).join.b
      db[:blobs].insert(data: Sequel.blob(bytes))
      expect(db[:blobs].select(:data).first[:data]).to eq(bytes)
    end

    it "returns the affected-row count from a delete" do
      db.run("CREATE TABLE items (name TEXT NOT NULL)")
      2.times { db[:items].insert(name: "foo") }
      expect(db[:items].where(name: "foo").delete).to eq(2)
    end

    it "reads a datetime('now') default column as a String" do
      db.run("CREATE TABLE stamped (at TEXT NOT NULL DEFAULT (datetime('now')))")
      db[:stamped].insert
      expect(db[:stamped].select(:at).first[:at]).to be_a(String)
    end
  end
end
