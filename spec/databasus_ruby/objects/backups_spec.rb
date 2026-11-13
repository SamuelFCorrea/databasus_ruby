# frozen_string_literal: true

require "stringio"

RSpec.describe DatabasusRuby::Backups do
  subject(:backups) { client.backups }

  let(:backup) do
    {
      "id" => "b1", "databaseId" => "db-1", "storageId" => "st-1", "status" => "COMPLETED",
      "sizeMb" => 12.5, "rawDatabaseSizeMb" => 80.0, "durationMs" => 4200, "encryption" => "NONE",
      "verificationStatus" => "NOT_VERIFIED", "createdAt" => "2026-11-01T03:00:00Z"
    }
  end

  describe "#list" do
    it "reads the cursor page and its totalUsageMb extra" do
      stub_api(:get, "logical-backups", query: { "databaseId" => "db-1", "limit" => "2" }, body: {
                 "totalUsageMb" => 1024.5,
                 "items" => [backup, { "id" => "b2", "status" => "FAILED", "failMessage" => "no space left" }],
                 "nextCursor" => "cur-2"
               })

      result = backups.list(database_id: "db-1", limit: 2)

      expect(result).to be_a(DatabasusRuby::Collection)
      expect(result.extras.total_usage_mb).to eq(1024.5)
      expect(result.next_cursor).to eq("cur-2")
      expect(result).not_to be_last_page
      expect(result.first.raw_database_size_mb).to eq(80.0)
      expect(result.last.fail_message).to eq("no space left")
    end

    it "sends a status array as repeated keys", :flat_query do
      url = "#{api_url("logical-backups")}?databaseId=db-1&status=COMPLETED&status=FAILED"
      stub_request(:get, url).to_return(
        status: 200, body: JSON.generate({ "totalUsageMb" => 0, "items" => [] }),
        headers: { "Content-Type" => "application/json" }
      )

      expect(backups.list(database_id: "db-1", status: %w[COMPLETED FAILED])).to be_last_page
      expect(WebMock).to have_requested(:get, url)
    end

    it "sends a single status as-is" do
      stub_api(:get, "logical-backups", query: { "databaseId" => "db-1", "status" => "COMPLETED" },
                                        body: { "totalUsageMb" => 0, "items" => [] })

      expect(backups.list(database_id: "db-1", status: "COMPLETED")).to be_empty
    end

    it "passes the remaining filters and the cursor under their api names" do
      query = { "databaseId" => "db-1", "createdBefore" => "2026-01-01T00:00:00Z", "after" => "cur-2" }
      stub_api(:get, "logical-backups", query: query, body: { "totalUsageMb" => 0, "items" => [] })

      backups.list(database_id: "db-1", created_before: "2026-01-01T00:00:00Z", after: "cur-2")

      expect(WebMock).to have_requested(:get, api_url("logical-backups")).with(query: query)
    end

    it "requires the database id" do
      expect { backups.list(database_id: nil) }.to raise_error(ArgumentError, /id is required/)
    end
  end

  describe "#get" do
    it "reads one backup" do
      stub_api(:get, "logical-backups/b1", body: backup)

      expect(backups.get("b1").verification_status).to eq("NOT_VERIFIED")
      expect(backups.find("b1").id).to eq("b1")
    end
  end

  describe "#create" do
    it "queues a backup for the database" do
      stub_api(:post, "logical-backups", status: 202, body: backup.merge("status" => "IN_PROGRESS"))

      expect(backups.create(database_id: "db-1").status).to eq("IN_PROGRESS")
      expect(WebMock).to have_requested(:post, api_url("logical-backups")).with(body: { "databaseId" => "db-1" })
    end

    it "is aliased as #trigger" do
      stub_api(:post, "logical-backups", status: 202, body: backup)

      expect(backups.trigger(database_id: "db-1")).to be_a(DatabasusRuby::Object)
    end

    it "surfaces the 409 when a backup is already running" do
      stub_api(:post, "logical-backups", status: 409, body: {
                 "title" => "Conflict", "status" => 409, "detail" => "a backup is already running",
                 "code" => "already_running"
               })

      expect { backups.create(database_id: "db-1") }
        .to raise_error(DatabasusRuby::ConflictError, "a backup is already running") do |error|
          expect(error.code).to eq("already_running")
        end
    end
  end

  describe "#delete and #cancel" do
    it "deletes and answers true on the 204" do
      stub_request(:delete, api_url("logical-backups/b1")).to_return(status: 204, body: "")

      expect(backups.delete("b1")).to be(true)
    end

    it "cancels and returns the backup" do
      stub_api(:post, "logical-backups/b1/cancel", body: backup.merge("status" => "CANCELED"))

      expect(backups.cancel("b1").status).to eq("CANCELED")
    end

    it "surfaces the conflict when a backup cannot be cancelled" do
      stub_api(:post, "logical-backups/b1/cancel", status: 409, body: {
                 "title" => "Conflict", "status" => 409, "detail" => "the backup is not in progress",
                 "code" => "not_in_progress"
               })

      expect { backups.cancel("b1") }
        .to raise_error(DatabasusRuby::ConflictError, "the backup is not in progress")
    end
  end

  describe "downloads" do
    let(:grant) { { "token" => "tok-1", "fileName" => "b1.dump", "expiresAt" => "2026-11-13T10:05:00Z" } }

    it "mints a download token through POST /download-tokens" do
      stub_api(:post, "download-tokens", status: 201, body: grant)

      result = backups.download_token("b1")

      expect(result.token).to eq("tok-1")
      expect(result.file_name).to eq("b1.dump")
      expect(WebMock).to have_requested(:post, api_url("download-tokens")).with(body: { "backupId" => "b1" })
    end

    it "returns the raw file body rather than trying to parse it" do
      stub_request(:get, api_url("logical-backups/b1/file"))
        .with(query: { "token" => "tok-1" })
        .to_return(status: 200, body: "\x1f\x8bbinary", headers: { "Content-Type" => "application/octet-stream" })

      expect(backups.file("b1", token: "tok-1")).to eq("\x1f\x8bbinary")
    end

    it "#download combines both steps in memory" do
      stub_api(:post, "download-tokens", status: 201, body: grant)
      stub_request(:get, api_url("logical-backups/b1/file"))
        .with(query: { "token" => "tok-1" })
        .to_return(status: 200, body: "dump", headers: { "Content-Type" => "application/octet-stream" })

      expect(backups.download("b1")).to eq(["b1.dump", "dump"])
    end

    it "#file_to streams with a token minted earlier and returns the byte count" do
      stub_request(:get, api_url("logical-backups/b1/file"))
        .with(query: { "token" => "tok-9" })
        .to_return(status: 200, body: "PGDMP", headers: { "Content-Type" => "application/octet-stream" })
      io = StringIO.new(+"")

      expect(backups.file_to("b1", io, token: "tok-9")).to eq(5)
      expect(io.string).to eq("PGDMP")
      expect(WebMock).not_to have_requested(:post, api_url("download-tokens"))
    end

    it "#download_to streams into the io and returns bytes and file name" do
      stub_api(:post, "download-tokens", status: 201, body: grant)
      stub_request(:get, api_url("logical-backups/b1/file"))
        .with(query: { "token" => "tok-1" })
        .to_return(status: 200, body: "PGDMP-contents", headers: { "Content-Type" => "application/octet-stream" })
      io = StringIO.new(+"")

      result = backups.download_to("b1", io)

      expect(io.string).to eq("PGDMP-contents")
      expect(result.bytes).to eq(14)
      expect(result.file_name).to eq("b1.dump")
      expect(result.expires_at).to eq("2026-11-13T10:05:00Z")
      expect(result.key?("token")).to be(false)
    end

    it "#download_to raises ConflictError with the code when the file is refused" do
      stub_api(:post, "download-tokens", status: 201, body: grant)
      stub_request(:get, api_url("logical-backups/b1/file")).with(query: { "token" => "tok-1" }).to_return(
        status: 409,
        body: JSON.generate({
                              "type" => "about:blank", "title" => "Conflict", "status" => 409,
                              "detail" => "too many downloads in progress", "code" => "download_limit_reached"
                            }),
        headers: { "Content-Type" => "application/problem+json" }
      )
      io = StringIO.new(+"")

      expect { backups.download_to("b1", io) }
        .to raise_error(DatabasusRuby::ConflictError, "too many downloads in progress") do |error|
          expect(error.code).to eq("download_limit_reached")
        end
      expect(io.string).to be_empty
    end

    it "propagates the token refusal before any file request" do
      stub_api(:post, "download-tokens", status: 409, body: {
                 "title" => "Conflict", "status" => 409, "detail" => "the backup is not completed",
                 "code" => "backup_not_completed"
               })

      expect { backups.download_to("b1", StringIO.new) }
        .to raise_error(DatabasusRuby::ConflictError, "the backup is not completed")
      expect(WebMock).not_to have_requested(:get, /file/)
    end
  end

  it "exposes the documented enums" do
    expect(described_class::STATUSES).to eq(%w[IN_PROGRESS COMPLETED FAILED CANCELED])
    expect(described_class::VERIFICATION_STATUSES).to include("VERIFIED_SUCCESSFUL")
  end
end
