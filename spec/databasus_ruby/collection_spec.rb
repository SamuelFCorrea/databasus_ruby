# frozen_string_literal: true

RSpec.describe DatabasusRuby::Collection do
  describe ".from" do
    it "reads a cursor page" do
      collection = described_class.from(
        { "items" => [{ "id" => "db-1", "name" => "a" }, { "id" => "db-2", "name" => "b" }], "nextCursor" => "c-2" }
      )

      expect(collection.map(&:name)).to eq(%w[a b])
      expect(collection.next_cursor).to eq("c-2")
      expect(collection).not_to be_last_page
    end

    it "treats a page without nextCursor as the last one" do
      collection = described_class.from({ "items" => [{ "id" => "w1" }] })

      expect(collection.next_cursor).to be_nil
      expect(collection).to be_last_page
    end

    it "treats an empty nextCursor as the last page" do
      expect(described_class.from({ "items" => [], "nextCursor" => "" })).to be_last_page
    end

    it "exposes page-level extras, as GET /logical-backups sends totalUsageMb" do
      collection = described_class.from(
        { "totalUsageMb" => 1536.25, "items" => [{ "id" => "b1" }], "nextCursor" => "c-1" }
      )

      expect(collection.extras).to be_a(DatabasusRuby::Object)
      expect(collection.extras.total_usage_mb).to eq(1536.25)
      expect(collection.extras.keys).to eq(["totalUsageMb"])
    end

    it "has empty extras when the page carries none" do
      expect(described_class.from({ "items" => [] }).extras.keys).to be_empty
    end

    it "wraps entries with the given builder" do
      wrap = ->(item) { DatabasusRuby::Object.new(item.merge("wrapped" => true)) }

      expect(described_class.from({ "items" => [{ "id" => "x" }] }, wrap: wrap).first.wrapped).to be(true)
    end

    it "handles a bare array, an empty page and a nil body" do
      expect(described_class.from([{ "id" => "a" }]).size).to eq(1)
      expect(described_class.from([{ "id" => "a" }])).to be_last_page
      expect(described_class.from({ "items" => [] })).to be_empty
      expect(described_class.from(nil)).to be_empty
      expect(described_class.from("")).to be_empty
    end

    it "raises on an unexpected payload" do
      expect { described_class.from("nope") }.to raise_error(DatabasusRuby::Error, /unexpected list payload/)
    end
  end

  it "is enumerable and indexable" do
    collection = described_class.from({ "items" => [{ "n" => 1 }, { "n" => 2 }, { "n" => 3 }] })

    expect(collection).to be_a(Enumerable)
    expect(collection.select { |item| item.n > 1 }.map(&:n)).to eq([2, 3])
    expect(collection[0].n).to eq(1)
    expect(collection.last.n).to eq(3)
    expect(collection.length).to eq(3)
    expect(collection.each_with_object([]) { |item, acc| acc << item.n }).to eq([1, 2, 3])
    expect(collection.each).to be_a(Enumerator)
  end

  it "shows its size and cursor in inspect" do
    expect(described_class.from({ "items" => [{}], "nextCursor" => "c" }).inspect)
      .to include("size=1", 'next_cursor="c"')
  end
end
