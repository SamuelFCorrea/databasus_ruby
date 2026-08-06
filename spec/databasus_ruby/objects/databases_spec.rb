# frozen_string_literal: true

RSpec.describe DatabasusRuby::Databases do
  subject(:databases) { client.databases }

  describe "#list" do
    it "reads the bare-array response into a Collection" do
      stub_api(:get, "databases", query: { "workspace_id" => "ws-1" }, body: [
                 { "id" => "db-1", "name" => "primary", "type" => "POSTGRES_LOGICAL" },
                 { "id" => "db-2", "name" => "replica", "type" => "MYSQL" }
               ])

      result = databases.list(workspace_id: "ws-1")

      expect(result).to be_a(DatabasusRuby::Collection)
      expect(result.total).to eq(2)
      expect(result.map(&:name)).to eq(%w[primary replica])
      expect(result.first.type).to eq("POSTGRES_LOGICAL")
    end
  end

  describe "#get" do
    it "fetches one database and exposes the engine-specific payload" do
      stub_api(:get, "databases/db-1", body: {
                 "id" => "db-1",
                 "name" => "primary",
                 "workspaceId" => "ws-1",
                 "postgresqlLogical" => { "host" => "10.0.0.1", "port" => 5432 }
               })

      database = databases.get("db-1")

      expect(database.name).to eq("primary")
      expect(database.workspace_id).to eq("ws-1")
      expect(database.postgresqlLogical.host).to eq("10.0.0.1")
    end

    it "refuses an empty id rather than requesting the collection" do
      expect { databases.get(nil) }.to raise_error(ArgumentError, /id is required/)
      expect { databases.get("") }.to raise_error(ArgumentError, /id is required/)
    end

    it "url-encodes the id" do
      stub_api(:get, "databases/db%2F1", body: { "id" => "db/1" })

      expect(databases.get("db/1").id).to eq("db/1")
    end
  end

  describe "#create" do
    it "posts to /databases/create" do
      stub_api(:post, "databases/create", status: 201, body: { "id" => "db-9", "name" => "primary" })

      created = databases.create(name: "primary", type: "POSTGRES_LOGICAL", workspaceId: "ws-1")

      expect(created.id).to eq("db-9")
      expect(WebMock).to have_requested(:post, api_url("databases/create"))
        .with(body: { "name" => "primary", "type" => "POSTGRES_LOGICAL", "workspaceId" => "ws-1" })
    end

    it "fills in the client default workspace" do
      stub_api(:post, "databases/create", status: 201, body: { "id" => "db-9" })

      client(workspace_id: "ws-default").databases.create(name: "primary")

      expect(WebMock).to have_requested(:post, api_url("databases/create"))
        .with(body: { "name" => "primary", "workspaceId" => "ws-default" })
    end

    it "does not override an explicit workspace" do
      stub_api(:post, "databases/create", status: 201, body: {})

      client(workspace_id: "ws-default").databases.create(name: "primary", workspaceId: "ws-explicit")

      expect(WebMock).to have_requested(:post, api_url("databases/create"))
        .with(body: { "name" => "primary", "workspaceId" => "ws-explicit" })
    end
  end

  describe "#update" do
    it "posts to /databases/update with the id in the body" do
      stub_api(:post, "databases/update", body: { "id" => "db-1", "name" => "renamed" })

      expect(databases.update(id: "db-1", name: "renamed").name).to eq("renamed")
      expect(WebMock).to have_requested(:post, api_url("databases/update"))
        .with(body: { "id" => "db-1", "name" => "renamed" })
    end
  end

  describe "#delete" do
    it "returns true on the 204" do
      stub_request(:delete, api_url("databases/db-1")).to_return(status: 204, body: "")

      expect(databases.delete("db-1")).to be(true)
    end
  end

  describe "#copy" do
    it "returns the new database" do
      stub_api(:post, "databases/db-1/copy", status: 201, body: { "id" => "db-2", "name" => "primary copy" })

      expect(databases.copy("db-1").name).to eq("primary copy")
    end
  end

  describe "connection tests" do
    it "returns true when a saved database answers" do
      stub_api(:post, "databases/db-1/test-connection", body: {})

      expect(databases.test_connection("db-1")).to be(true)
    end

    it "raises the API error when it does not" do
      stub_api(:post, "databases/db-1/test-connection", status: 400, body: { "error" => "dial tcp: refused" })

      expect { databases.test_connection("db-1") }
        .to raise_error(DatabasusRuby::BadRequestError, "dial tcp: refused")
    end

    it "tests an unsaved payload directly" do
      stub_api(:post, "databases/test-connection-direct", body: {})

      expect(databases.test_connection_direct(type: "MYSQL", mysql: { "host" => "db" })).to be(true)
      expect(WebMock).to have_requested(:post, api_url("databases/test-connection-direct"))
        .with(body: { "type" => "MYSQL", "mysql" => { "host" => "db" } })
    end
  end

  describe "user provisioning" do
    it "returns the generated read-only credentials" do
      stub_api(:post, "databases/create-readonly-user", body: { "username" => "ro_1", "password" => "s3cret" })

      credentials = databases.create_readonly_user(id: "db-1")

      expect(credentials.username).to eq("ro_1")
      expect(credentials.password).to eq("s3cret")
    end

    it "returns the generated replication credentials" do
      stub_api(:post, "databases/create-replication-only-user", body: { "username" => "repl_1" })

      expect(databases.create_replication_only_user(id: "db-1").username).to eq("repl_1")
    end

    it "reports read-only status and privileges" do
      stub_api(:post, "databases/is-readonly", body: { "isReadOnly" => true, "privileges" => %w[SELECT] })

      expect(databases.readonly(id: "db-1").privileges).to eq(%w[SELECT])
      expect(databases.readonly?(id: "db-1")).to be(true)
    end

    it "reports a writable user as not read-only" do
      stub_api(:post, "databases/is-readonly", body: { "isReadOnly" => false })

      expect(databases.readonly?(id: "db-1")).to be(false)
    end
  end

  describe "backups" do
    it "lists the backups of one database" do
      stub_api(:get, "backups", query: { "database_id" => "db-1" }, body: {
                 "backups" => [{ "id" => "b1", "status" => "COMPLETED" }], "total" => 1
               })

      result = databases.backups("db-1")

      expect(result).to be_a(DatabasusRuby::Collection)
      expect(result.first.id).to eq("b1")
    end

    it "passes the Backups#list filters through" do
      stub_api(:get, "backups",
               query: { "database_id" => "db-1", "status" => "COMPLETED,FAILED", "limit" => "2" },
               body: { "backups" => [] })

      databases.backups("db-1", status: %w[COMPLETED FAILED], limit: 2)

      expect(WebMock).to have_requested(:get, api_url("backups"))
        .with(query: { "database_id" => "db-1", "status" => "COMPLETED,FAILED", "limit" => "2" })
    end

    it "queues a backup run" do
      stub_api(:post, "backups", body: { "message" => "backup started" })

      expect(databases.backup("db-1").message).to eq("backup started")
      expect(WebMock).to have_requested(:post, api_url("backups")).with(body: { "database_id" => "db-1" })
    end

    it "refuses an empty id" do
      expect { databases.backups(nil) }.to raise_error(ArgumentError, /id is required/)
      expect { databases.backup("") }.to raise_error(ArgumentError, /id is required/)
    end
  end

  describe "a database record" do
    it "reaches its own backups" do
      stub_api(:get, "databases/db-1", body: { "id" => "db-1", "name" => "primary" })
      stub_api(:get, "backups", query: { "database_id" => "db-1", "status" => "COMPLETED" },
                                body: { "backups" => [{ "id" => "b1" }], "total" => 1 })

      database = databases.get("db-1")

      expect(database).to be_a(DatabasusRuby::Database)
      expect(database.backups(status: "COMPLETED").first.id).to eq("b1")
    end

    it "queues its own backup run" do
      stub_api(:get, "databases/db-1", body: { "id" => "db-1" })
      stub_api(:post, "backups", body: { "message" => "backup started" })

      expect(databases.get("db-1").backup.message).to eq("backup started")
      expect(WebMock).to have_requested(:post, api_url("backups")).with(body: { "database_id" => "db-1" })
    end

    it "comes back from #list and #create too" do
      stub_api(:get, "databases", query: { "workspace_id" => "ws-1" }, body: [{ "id" => "db-1" }])
      stub_api(:post, "databases/create", body: { "id" => "db-2" })

      expect(databases.list(workspace_id: "ws-1").first).to be_a(DatabasusRuby::Database)
      expect(databases.create(name: "primary", workspaceId: "ws-1")).to be_a(DatabasusRuby::Database)
    end

    it "says so instead of requesting a nil database_id when the payload has no id" do
      stub_api(:get, "databases/db-1", body: { "name" => "primary" })

      expect { databases.get("db-1").backups }
        .to raise_error(DatabasusRuby::Error, /no id/)
    end
  end

  describe "notifier usage" do
    it "unwraps the single-entry count map" do
      stub_api(:get, "databases/notifier/n-1/databases-count", body: { "count" => 3 })

      expect(databases.notifier_databases_count("n-1")).to eq(3)
    end

    it "unwraps the single-entry boolean map" do
      stub_api(:get, "databases/notifier/n-1/is-using", body: { "isUsing" => true })

      expect(databases.notifier_using?("n-1")).to be(true)
    end
  end

  it "exposes the documented enums" do
    expect(described_class::TYPES).to include("POSTGRES_LOGICAL", "MONGODB")
    expect(described_class::HEALTH_STATUSES).to eq(%w[AVAILABLE UNAVAILABLE])
  end
end
