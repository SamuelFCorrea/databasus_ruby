# frozen_string_literal: true

RSpec.describe DatabasusRuby::Storages do
  subject(:storages) { client.storages }

  let(:storage) do
    { "id" => "st-1", "workspaceId" => "ws-1", "name" => "offsite",
      "settings" => { "type" => "S3", "bucket" => "backups", "region" => "us-east-1" } }
  end

  describe "#list" do
    it "reads the cursor page for the workspace" do
      stub_api(:get, "storages", query: { "workspaceId" => "ws-1", "after" => "cur-1" }, body: { "items" => [storage] })

      result = storages.list(workspace_id: "ws-1", after: "cur-1")

      expect(result.first.settings.bucket).to eq("backups")
      expect(result).to be_last_page
    end

    it "requires a workspace" do
      expect { storages.list }.to raise_error(DatabasusRuby::ConfigurationError, /workspace_id is required/)
    end
  end

  describe "#get" do
    it "reads one storage" do
      stub_api(:get, "storages/st-1", body: storage)

      expect(storages.get("st-1").name).to eq("offsite")
      expect(storages.find("st-1").id).to eq("st-1")
    end
  end

  describe "#create" do
    it "posts to /storages with the client default workspace" do
      stub_api(:post, "storages", status: 201, body: storage)

      client(workspace_id: "ws-1").storages.create(name: "offsite", settings: { type: "S3", bucket: "backups" })

      expect(WebMock).to have_requested(:post, api_url("storages")).with(
        body: { "workspaceId" => "ws-1", "name" => "offsite", "settings" => { "type" => "S3", "bucket" => "backups" } }
      )
    end
  end

  describe "#update" do
    it "puts name and settings to /storages/{id}" do
      stub_api(:put, "storages/st-1", body: storage.merge("name" => "cold"))

      expect(storages.update("st-1", name: "cold", settings: { type: "S3" }).name).to eq("cold")
      expect(WebMock).to have_requested(:put, api_url("storages/st-1"))
        .with(body: { "name" => "cold", "settings" => { "type" => "S3" } })
    end
  end

  describe "#delete" do
    it "deletes" do
      stub_request(:delete, api_url("storages/st-1")).to_return(status: 204, body: "")

      expect(storages.delete("st-1")).to be(true)
    end

    it "surfaces the conflict when databases still use the storage" do
      stub_api(:delete, "storages/st-1", status: 409, body: {
                 "title" => "Conflict", "status" => 409, "detail" => "the storage is in use", "code" => "storage_in_use"
               })

      expect { storages.delete("st-1") }.to raise_error(DatabasusRuby::ConflictError) do |error|
        expect(error.code).to eq("storage_in_use")
      end
    end
  end

  describe "#backup_usage, #test and #transfer" do
    it "reads the backup usage" do
      stub_api(:get, "storages/st-1/backup-usage", body: { "totalSizeMb" => 2048.0, "backupsCount" => 12 })

      expect(storages.backup_usage("st-1").total_size_mb).to eq(2048.0)
    end

    it "tests the storage" do
      stub_request(:post, api_url("storages/st-1/test")).to_return(status: 204, body: "")

      expect(storages.test("st-1")).to be_a(DatabasusRuby::Object)
      expect(WebMock).to have_requested(:post, api_url("storages/st-1/test"))
    end

    it "transfers to another workspace" do
      stub_api(:post, "storages/st-1/transfer", body: storage.merge("workspaceId" => "ws-2"))

      expect(storages.transfer("st-1", target_workspace_id: "ws-2").workspace_id).to eq("ws-2")
      expect(WebMock).to have_requested(:post, api_url("storages/st-1/transfer"))
        .with(body: { "targetWorkspaceId" => "ws-2" })
    end
  end

  it "exposes the documented types" do
    expect(described_class::TYPES).to include("LOCAL", "S3", "SFTP")
  end
end
