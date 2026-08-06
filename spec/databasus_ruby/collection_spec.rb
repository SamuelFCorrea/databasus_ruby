# frozen_string_literal: true

RSpec.describe DatabasusRuby::Collection do
  describe ".from" do
    it "handles a bare array response, as GET /databases sends" do
      collection = described_class.from([{ "name" => "a" }, { "name" => "b" }], key: "databases")

      expect(collection.map(&:name)).to eq(%w[a b])
      expect(collection.total).to eq(2)
      expect(collection.limit).to be_nil
      expect(collection).not_to be_paginated
    end

    it "handles a paginated envelope, as GET /backups sends" do
      collection = described_class.from(
        { "backups" => [{ "id" => "b1" }], "total" => 42, "limit" => 1, "offset" => 0 },
        key: "backups"
      )

      expect(collection.size).to eq(1)
      expect(collection.total).to eq(42)
      expect(collection.limit).to eq(1)
      expect(collection.offset).to eq(0)
      expect(collection).to be_paginated
    end

    it "handles an unpaginated envelope, as GET /workspaces sends" do
      collection = described_class.from({ "workspaces" => [{ "id" => "w1" }] }, key: "workspaces")

      expect(collection.total).to eq(1)
      expect(collection).not_to be_paginated
    end

    it "handles an empty envelope and a nil body" do
      expect(described_class.from({ "workspaces" => [] }, key: "workspaces")).to be_empty
      expect(described_class.from(nil, key: "workspaces")).to be_empty
    end

    it "raises on an unexpected payload" do
      expect { described_class.from("nope", key: "x") }.to raise_error(DatabasusRuby::Error)
    end
  end

  describe "pagination arithmetic" do
    it "computes the next offset while pages remain" do
      collection = described_class.from(
        { "backups" => Array.new(10) { { "id" => "b" } }, "total" => 25, "limit" => 10, "offset" => 10 },
        key: "backups"
      )

      expect(collection.next_offset).to eq(20)
      expect(collection).not_to be_last_page
    end

    it "reports the last page" do
      collection = described_class.from(
        { "backups" => Array.new(5) { { "id" => "b" } }, "total" => 25, "limit" => 10, "offset" => 20 },
        key: "backups"
      )

      expect(collection.next_offset).to be_nil
      expect(collection).to be_last_page
    end

    it "treats an unpaginated list as a single page" do
      expect(described_class.from([{ "a" => 1 }], key: "x")).to be_last_page
    end
  end

  it "is enumerable and indexable" do
    collection = described_class.from([{ "n" => 1 }, { "n" => 2 }, { "n" => 3 }], key: "x")

    expect(collection).to be_a(Enumerable)
    expect(collection.select { |item| item.n > 1 }.map(&:n)).to eq([2, 3])
    expect(collection[0].n).to eq(1)
    expect(collection.last.n).to eq(3)
    expect(collection.length).to eq(3)
    expect(collection.each_with_object([]) { |item, acc| acc << item.n }).to eq([1, 2, 3])
  end
end
