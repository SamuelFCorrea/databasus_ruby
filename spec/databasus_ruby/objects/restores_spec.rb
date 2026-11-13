# frozen_string_literal: true

RSpec.describe DatabasusRuby::Restores do
  subject(:restores) { client.restores }

  let(:restore) do
    { "id" => "r1", "backupId" => "b1", "status" => "IN_PROGRESS", "durationMs" => 0,
      "createdAt" => "2026-11-13T10:00:00Z" }
  end

  let(:target) do
    described_class.postgresql_target(host: "db.internal", port: 5432, username: "app", password: "secret",
                                      database: "copy_of_prod")
  end

  describe ".postgresql_target" do
    it "builds a POSTGRES_LOGICAL target with safe defaults" do
      expect(target).to eq(
        type: "POSTGRES_LOGICAL",
        host: "db.internal",
        port: 5432,
        username: "app",
        password: "secret",
        database: "copy_of_prod",
        sslMode: "disable",
        sshTunnel: { isEnabled: false },
        cpuCount: 1,
        isExcludeExtensions: false,
        isRestoreOwnership: false,
        isRestorePrivileges: false
      )
    end

    it "takes the optional settings" do
      tunnel = { isEnabled: true, host: "bastion", port: 22 }
      custom = described_class.postgresql_target(
        host: "h", port: 6432, username: "u", password: "p", database: "d", ssl_mode: "require", cpu_count: 4,
        exclude_extensions: true, restore_ownership: true, restore_privileges: true, ssh_tunnel: tunnel
      )

      expect(custom).to include(sslMode: "require", cpuCount: 4, isExcludeExtensions: true,
                                isRestoreOwnership: true, isRestorePrivileges: true, sshTunnel: tunnel)
    end
  end

  describe "#start" do
    it "posts the backup and the target to /restores" do
      stub_api(:post, "restores", status: 202, body: restore)

      result = restores.start(backup_id: "b1", target: target)

      expect(result.id).to eq("r1")
      expect(result.status).to eq("IN_PROGRESS")
      expect(WebMock).to have_requested(:post, api_url("restores")).with(body: {
                                                                           "backupId" => "b1",
                                                                           "target" => JSON.parse(JSON.generate(target))
                                                                         })
    end

    it "is aliased as #create" do
      stub_api(:post, "restores", status: 202, body: restore)

      expect(restores.create(backup_id: "b1", target: target).backup_id).to eq("b1")
    end

    it "requires the backup id" do
      expect { restores.start(backup_id: "", target: target) }.to raise_error(ArgumentError, /id is required/)
    end

    it "surfaces the problem when the target cannot take the restore" do
      stub_api(:post, "restores", status: 409, body: {
                 "title" => "Conflict", "status" => 409, "detail" => "not enough disk space for the restore",
                 "code" => "insufficient_disk_space"
               })

      expect { restores.start(backup_id: "b1", target: target) }
        .to raise_error(DatabasusRuby::ConflictError) { |error| expect(error.code).to eq("insufficient_disk_space") }
    end
  end

  describe "#get" do
    it "reads one restore" do
      stub_api(:get, "restores/r1",
               body: restore.merge("status" => "FAILED", "failMessage" => "role \"app\" does not exist"))

      result = restores.get("r1")

      expect(result.status).to eq("FAILED")
      expect(result.fail_message).to include("does not exist")
      expect(restores.find("r1").id).to eq("r1")
    end
  end

  describe "#list" do
    it "lists the restores of a backup as a cursor page" do
      stub_api(:get, "restores", query: { "backupId" => "b1", "limit" => "10", "after" => "cur-1" },
                                 body: { "items" => [restore], "nextCursor" => "cur-2" })

      page = restores.list(backup_id: "b1", limit: 10, after: "cur-1")

      expect(page.map(&:id)).to eq(["r1"])
      expect(page.next_cursor).to eq("cur-2")
    end

    it "requires the backup id" do
      expect { restores.list(backup_id: nil) }.to raise_error(ArgumentError, /id is required/)
    end
  end

  describe "#cancel" do
    it "posts to /restores/{id}/cancel" do
      stub_api(:post, "restores/r1/cancel", body: restore.merge("status" => "CANCELED"))

      expect(restores.cancel("r1").status).to eq("CANCELED")
      expect(WebMock).to have_requested(:post, api_url("restores/r1/cancel"))
    end
  end

  it "exposes the documented enums" do
    expect(described_class::STATUSES).to eq(%w[IN_PROGRESS COMPLETED FAILED CANCELED])
    expect(described_class::SSL_MODES).to include("verify-full")
  end
end
