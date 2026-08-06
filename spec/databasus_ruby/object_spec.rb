# frozen_string_literal: true

RSpec.describe DatabasusRuby::Object do
  subject(:object) do
    described_class.new(
      "id" => "db-1",
      "name" => "primary",
      "workspaceId" => "ws-1",
      "postgresqlLogical" => { "host" => "localhost", "port" => 5432 },
      "notifiers" => [{ "name" => "ops" }, { "name" => "oncall" }],
      "database_id" => "raw-snake"
    )
  end

  it "reads top-level attributes" do
    expect(object.name).to eq("primary")
    expect(object.id).to eq("db-1")
  end

  it "wraps nested hashes so the whole tree reads the same way" do
    expect(object.postgresqlLogical).to be_a(described_class)
    expect(object.postgresqlLogical.host).to eq("localhost")
    expect(object.postgresqlLogical.port).to eq(5432)
  end

  it "wraps arrays of hashes" do
    expect(object.notifiers.map(&:name)).to eq(%w[ops oncall])
  end

  it "accepts snake_case for camelCase keys" do
    expect(object.workspace_id).to eq("ws-1")
  end

  it "prefers an exact key match over the camelCase fallback" do
    expect(object.database_id).to eq("raw-snake")
  end

  it "returns nil for keys the API omitted" do
    expect(object.lastBackupErrorMessage).to be_nil
    expect(object.totally_absent).to be_nil
  end

  it "supports hash-style access and conversion" do
    expect(object["name"]).to eq("primary")
    expect(object[:workspace_id]).to eq("ws-1")
    expect(object.to_h["name"]).to eq("primary")
    expect(object.keys).to include("id", "name")
  end

  it "reports key presence" do
    expect(object.key?("name")).to be(true)
    expect(object.key?(:workspace_id)).to be(true)
    expect(object.key?("nope")).to be(false)
  end

  it "compares by payload" do
    expect(described_class.new("a" => 1)).to eq(described_class.new("a" => 1))
    expect(described_class.new("a" => 1)).not_to eq(described_class.new("a" => 2))
  end

  it "symbolizes nothing but stringifies keys" do
    expect(described_class.new(name: "x").name).to eq("x")
  end

  it "hides the api payload from inspect noise" do
    expect(object.inspect).to include("id", "name")
  end

  context "when subclassed as an endpoint" do
    it "raises NoMethodError instead of answering nil" do
      endpoint = DatabasusRuby::Databases.new(:client)

      expect { endpoint.not_an_endpoint }.to raise_error(NoMethodError)
      expect(endpoint).not_to respond_to(:not_an_endpoint)
    end
  end
end
