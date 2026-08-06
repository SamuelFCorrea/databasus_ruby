# frozen_string_literal: true

RSpec.describe DatabasusRuby::Backups do
  subject(:backups) { client.backups }

  describe "#list" do
    it "reads the paginated envelope" do
      stub_api(:get, "backups", query: { "database_id" => "db-1", "limit" => "2", "offset" => "0" }, body: {
                 "backups" => [
                   { "id" => "b1", "fileName" => "b1.sql.gz", "status" => "COMPLETED", "backupSizeMb" => 12.5 },
                   { "id" => "b2", "status" => "FAILED", "failMessage" => "no space left" }
                 ],
                 "total" => 7, "limit" => 2, "offset" => 0
               })

      result = backups.list(database_id: "db-1", limit: 2, offset: 0)

      expect(result.total).to eq(7)
      expect(result.next_offset).to eq(2)
      expect(result.first.fileName).to eq("b1.sql.gz")
      expect(result.last.failMessage).to eq("no space left")
    end

    it "sends a status array as csv" do
      stub_api(:get, "backups",
               query: { "database_id" => "db-1", "status" => "COMPLETED,FAILED" },
               body: { "backups" => [] })

      backups.list(database_id: "db-1", status: %w[COMPLETED FAILED])

      expect(WebMock).to have_requested(:get, api_url("backups"))
        .with(query: { "database_id" => "db-1", "status" => "COMPLETED,FAILED" })
    end

    it "sends a single status as-is" do
      stub_api(:get, "backups", query: { "database_id" => "db-1", "status" => "COMPLETED" },
                                body: { "backups" => [] })

      expect(backups.list(database_id: "db-1", status: "COMPLETED")).to be_empty
    end

    it "passes the remaining filters through under their api names" do
      stub_api(:get, "backups",
               query: { "database_id" => "db-1", "beforeDate" => "2026-01-01T00:00:00Z", "pgWalBackupType" => "WAL" },
               body: { "backups" => [] })

      backups.list(database_id: "db-1", before_date: "2026-01-01T00:00:00Z", pg_wal_backup_type: "WAL")

      expect(WebMock).to have_requested(:get, api_url("backups")).with(
        query: { "database_id" => "db-1", "beforeDate" => "2026-01-01T00:00:00Z", "pgWalBackupType" => "WAL" }
      )
    end
  end

  describe "#create" do
    it "queues a backup for the database" do
      stub_api(:post, "backups", body: { "message" => "backup started" })

      expect(backups.create(database_id: "db-1").message).to eq("backup started")
      expect(WebMock).to have_requested(:post, api_url("backups")).with(body: { "database_id" => "db-1" })
    end

    it "is aliased as #trigger" do
      stub_api(:post, "backups", body: {})

      expect(backups.trigger(database_id: "db-1")).to be_a(DatabasusRuby::Object)
    end
  end

  describe "#delete and #cancel" do
    it "returns true on the 204s" do
      stub_request(:delete, api_url("backups/b1")).to_return(status: 204, body: "")
      stub_request(:post, api_url("backups/b1/cancel")).to_return(status: 204, body: "")

      expect(backups.delete("b1")).to be(true)
      expect(backups.cancel("b1")).to be(true)
    end

    it "surfaces the conflict when a backup cannot be cancelled" do
      stub_api(:post, "backups/b1/cancel", status: 400, body: { "error" => "backup is not in progress" })

      expect { backups.cancel("b1") }
        .to raise_error(DatabasusRuby::BadRequestError, "backup is not in progress")
    end
  end

  describe "downloads" do
    it "mints a download token" do
      stub_api(:post, "backups/b1/download-token",
               body: { "token" => "tok-1", "filename" => "b1.sql.gz", "backupId" => "b1" })

      grant = backups.download_token("b1")

      expect(grant.token).to eq("tok-1")
      expect(grant.filename).to eq("b1.sql.gz")
    end

    it "returns the raw file body rather than trying to parse it" do
      stub_request(:get, api_url("backups/b1/file"))
        .with(query: { "token" => "tok-1" })
        .to_return(status: 200, body: "\x1f\x8bbinary", headers: { "Content-Type" => "application/gzip" })

      expect(backups.file("b1", token: "tok-1")).to eq("\x1f\x8bbinary")
    end

    it "#download combines both steps" do
      stub_api(:post, "backups/b1/download-token", body: { "token" => "tok-1", "filename" => "b1.sql.gz" })
      stub_request(:get, api_url("backups/b1/file"))
        .with(query: { "token" => "tok-1" })
        .to_return(status: 200, body: "dump", headers: { "Content-Type" => "application/gzip" })

      expect(backups.download("b1")).to eq(["b1.sql.gz", "dump"])
    end

    it "propagates the 409 when the backup is not downloadable" do
      stub_api(:post, "backups/b1/download-token", status: 409, body: { "error" => "backup not completed" })

      expect { backups.download("b1") }
        .to raise_error(DatabasusRuby::ConflictError, "backup not completed")
    end
  end

  it "exposes the documented enums" do
    expect(described_class::STATUSES).to eq(%w[IN_PROGRESS COMPLETED FAILED CANCELED])
    expect(described_class::ENCRYPTIONS).to eq(%w[NONE ENCRYPTED])
    expect(described_class::VERIFICATION_STATUSES).to include("VERIFIED_SUCCESSFUL")
  end
end
