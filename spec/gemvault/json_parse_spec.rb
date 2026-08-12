require "gemvault/json"

RSpec.describe Gemvault::Json, ".parse" do
  it "parses an object with symbolized keys" do
    expect(described_class.parse('{"name": "foo"}')).to eq(name: "foo")
  end

  it "parses nested objects and arrays" do
    json = '{"gems": [{"name": "a", "encrypted": false}, {"name": "b", "encrypted": true}]}'
    expect(described_class.parse(json))
      .to eq(gems: [{ name: "a", encrypted: false }, { name: "b", encrypted: true }])
  end

  it "parses integers and floats" do
    expect(described_class.parse('{"size": 1024, "ratio": -1.5e2}')).to eq(size: 1024, ratio: -150.0)
  end

  it "parses null, true and false" do
    expect(described_class.parse("[null, true, false]")).to eq([nil, true, false])
  end

  it "parses empty containers" do
    expect(described_class.parse('{"gems": [], "meta": {}}')).to eq(gems: [], meta: {})
  end

  it "parses escaped characters in strings" do
    expect(described_class.parse('["a\\"b\\\\c\\/d\\n\\t"]')).to eq(["a\"b\\c/d\n\t"])
  end

  it "parses unicode escapes" do
    expect(described_class.parse('["caf\\u00e9"]')).to eq(["café"])
  end

  it "parses surrogate pairs" do
    expect(described_class.parse('["\\ud83d\\ude00"]').first.codepoints).to eq([0x1F600])
  end

  it "parses raw UTF-8 without escapes" do
    expect(described_class.parse('["café"]')).to eq(["café"])
  end

  it "tolerates arbitrary whitespace" do
    expect(described_class.parse(%( {\n  "a" : [ 1 , 2 ]\n} ))).to eq(a: [1, 2])
  end

  it "raises ParseError on malformed input" do
    expect { described_class.parse('{"a": }') }.to raise_error(Gemvault::Json::ParseError)
  end

  it "raises ParseError on trailing garbage" do
    expect { described_class.parse("{} {}") }.to raise_error(Gemvault::Json::ParseError)
  end

  it "raises ParseError on an unterminated string" do
    expect { described_class.parse('["abc') }.to raise_error(Gemvault::Json::ParseError)
  end
end
