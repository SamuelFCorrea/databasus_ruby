# frozen_string_literal: true

RSpec.describe DatabasusRuby::Databases do
  subject(:databases) { client.databases }

  let(:database) do
    {
      "id" => "db-1", "workspaceId" => "ws-1", "name" => "primary", "notifierIds" => ["n-1"],
      "settings" => { "type" => "POSTGRES_LOGICAL", "host" => "10.0.0.1", "port" => 5432, "database" => "app" },
      "healthStatus" => "AVAILABLE"
    }
  end

  describe "#list" do
    it "reads the cursor page into a Collection of Database records" do
      stub_api(:get, "databases", query: { "workspaceId" => "ws-1" }, body: {
                 "items" => [database, database.merge("id" => "db-2", "name" => "replica")]
               })

      result = databases.list(workspace_id: "ws-1")

      expect(result).to be_a(DatabasusRuby::Collection)
      expect(result.first).to be_a(DatabasusRuby::Database)
      expect(result.map(&:name)).to eq(%w[primary replica])
      expect(result.first.settings.type).to eq("POSTGRES_LOGICAL")
      expect(result).to be_last_page
    end

    it "passes the notifier filter and the cursor" do
      query = { "workspaceId" => "ws-1", "notifierId" => "n-1", "limit" => "5", "after" => "cur-1" }
      stub_api(:get, "databases", query: query, body: { "items" => [] })

      databases.list(workspace_id: "ws-1", notifier_id: "n-1", limit: 5, after: "cur-1")

      expect(WebMock).to have_requested(:get, api_url("databases")).with(query: query)
    end
  end

  describe "#list_all" do
    it "follows nextCursor across pages" do
      stub_api(:get, "databases", query: { "workspaceId" => "ws-1", "limit" => "1" },
                                  body: { "items" => [database], "nextCursor" => "cur-2" })
      stub_api(:get, "databases", query: { "workspaceId" => "ws-1", "limit" => "1", "after" => "cur-2" },
                                  body: { "items" => [database.merge("id" => "db-2", "name" => "replica")] })

      result = databases.list_all(workspace_id: "ws-1", limit: 1)

      expect(result).to be_an(Array)
      expect(result.map(&:id)).to eq(%w[db-1 db-2])
      expect(result).to all(be_a(DatabasusRuby::Database))
      expect(WebMock).to have_requested(:get, /databases/).twice
    end

    it "asks for 100 per page by default and uses the client workspace" do
      stub_api(:get, "databases", query: { "workspaceId" => "ws-default", "limit" => "100" }, body: { "items" => [] })

      expect(client(workspace_id: "ws-default").databases.list_all).to eq([])
    end
  end

  describe "#get" do
    it "fetches one database and exposes the engine-specific settings" do
      stub_api(:get, "databases/db-1", body: database)

      result = databases.get("db-1")

      expect(result).to be_a(DatabasusRuby::Database)
      expect(result.workspace_id).to eq("ws-1")
      expect(result.settings.host).to eq("10.0.0.1")
      expect(result.notifier_ids).to eq(["n-1"])
    end

    it "refuses an empty id rather than requesting the collection" do
      expect { databases.get(nil) }.to raise_error(ArgumentError, /id is required/)
      expect { databases.get("") }.to raise_error(ArgumentError, /id is required/)
    end

    it "url-encodes the id" do
      stub_api(:get, "databases/db%2F1", body: { "id" => "db/1" })

      expect(databases.find("db/1").id).to eq("db/1")
    end
  end

  describe "#create" do
    let(:payload) do
      { name: "primary", notifierIds: [], settings: { type: "POSTGRES_LOGICAL", host: "10.0.0.1", port: 5432 } }
    end

    it "posts to /databases" do
      stub_api(:post, "databases", status: 201, body: database)

      created = databases.create(workspaceId: "ws-1", **payload)

      expect(created).to be_a(DatabasusRuby::Database)
      expect(created.id).to eq("db-1")
      expect(WebMock).to have_requested(:post, api_url("databases")).with(
        body: {
          "workspaceId" => "ws-1", "name" => "primary", "notifierIds" => [],
          "settings" => { "type" => "POSTGRES_LOGICAL", "host" => "10.0.0.1", "port" => 5432 }
        }
      )
    end

    it "fills in the client default workspace" do
      stub_api(:post, "databases", status: 201, body: database)

      client(workspace_id: "ws-default").databases.create(**payload)

      expect(WebMock).to(have_requested(:post, api_url("databases"))
        .with { |request| JSON.parse(request.body)["workspaceId"] == "ws-default" })
    end

    it "keeps an explicit workspace over the default" do
      stub_api(:post, "databases", status: 201, body: database)

      client(workspace_id: "ws-default").databases.create(workspaceId: "ws-1", **payload)

      expect(WebMock).to(have_requested(:post, api_url("databases"))
        .with { |request| JSON.parse(request.body)["workspaceId"] == "ws-1" })
    end
  end

  describe "#update" do
    it "puts the full payload to /databases/{id}" do
      stub_api(:put, "databases/db-1", body: database.merge("name" => "renamed"))

      updated = databases.update("db-1", name: "renamed", notifierIds: ["n-1"], settings: { type: "POSTGRES_LOGICAL" })

      expect(updated.name).to eq("renamed")
      expect(WebMock).to have_requested(:put, api_url("databases/db-1")).with(
        body: { "name" => "renamed", "notifierIds" => ["n-1"], "settings" => { "type" => "POSTGRES_LOGICAL" } }
      )
    end
  end

  describe "#delete and #copy" do
    it "deletes and answers true" do
      stub_request(:delete, api_url("databases/db-1")).to_return(status: 204, body: "")

      expect(databases.delete("db-1")).to be(true)
    end

    it "copies into a new Database" do
      stub_api(:post, "databases/db-1/copy", status: 201,
                                             body: database.merge("id" => "db-3", "name" => "primary (copy)"))

      copy = databases.copy("db-1")

      expect(copy).to be_a(DatabasusRuby::Database)
      expect(copy.id).to eq("db-3")
    end
  end

  describe "#test and #connected?" do
    it "posts to /databases/{id}/test and returns the result" do
      stub_api(:post, "databases/db-1/test", body: {
                 "isConnected" => false, "reason" => "BAD_CREDENTIALS", "error" => "password authentication failed"
               })

      result = databases.test("db-1")

      expect(result.is_connected).to be(false)
      expect(result.reason).to eq("BAD_CREDENTIALS")
    end

    it "answers connected? from isConnected" do
      stub_api(:post, "databases/db-1/test", body: { "isConnected" => true })
      stub_api(:post, "databases/db-2/test", body: { "isConnected" => false, "reason" => "CONNECTION_FAILED" })

      expect(databases.connected?("db-1")).to be(true)
      expect(databases.connected?("db-2")).to be(false)
    end
  end

  describe "backups by id" do
    it "#backups lists the logical backups of the database" do
      stub_api(:get, "logical-backups", query: { "databaseId" => "db-1", "status" => "COMPLETED" },
                                        body: { "totalUsageMb" => 1.0, "items" => [{ "id" => "b1" }] })

      expect(databases.backups("db-1", status: "COMPLETED").map(&:id)).to eq(["b1"])
    end

    it "#backup queues a run" do
      stub_api(:post, "logical-backups", status: 202, body: { "id" => "b9", "status" => "IN_PROGRESS" })

      expect(databases.backup("db-1").id).to eq("b9")
      expect(WebMock).to have_requested(:post, api_url("logical-backups")).with(body: { "databaseId" => "db-1" })
    end

    it "requires the id" do
      expect { databases.backups(nil) }.to raise_error(ArgumentError, /id is required/)
      expect { databases.backup("") }.to raise_error(ArgumentError, /id is required/)
    end
  end

  describe DatabasusRuby::Database do
    it "reaches its backups through the client it came from" do
      stub_api(:get, "databases/db-1", body: database)
      stub_api(:get, "logical-backups", query: { "databaseId" => "db-1", "limit" => "1" },
                                        body: { "totalUsageMb" => 5.5, "items" => [{ "id" => "b1" }] })
      stub_api(:post, "logical-backups", status: 202, body: { "id" => "b2" })

      record = databases.get("db-1")

      expect(record.backups(limit: 1).extras.total_usage_mb).to eq(5.5)
      expect(record.backup.id).to eq("b2")
    end

    it "refuses to reach related endpoints without an id" do
      record = described_class.new(client, { "name" => "partial" })

      expect { record.backups }.to raise_error(DatabasusRuby::Error, /has no id/)
      expect { record.backup }.to raise_error(DatabasusRuby::Error, /has no id/)
    end
  end

  it "exposes the documented types" do
    expect(described_class::TYPES).to eq(%w[POSTGRES_LOGICAL POSTGRES_PHYSICAL MYSQL MARIADB MONGODB])
  end
end
