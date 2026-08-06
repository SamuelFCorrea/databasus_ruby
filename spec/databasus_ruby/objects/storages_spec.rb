# frozen_string_literal: true

RSpec.describe DatabasusRuby::Storages do
  subject(:storages) { client.storages }

  describe "#list" do
    it "reads the bare-array response" do
      stub_api(:get, "storages", query: { "workspace_id" => "ws-1" }, body: [
                 { "id" => "st-1", "name" => "offsite", "type" => "S3",
                   "s3Storage" => { "bucket" => "backups", "region" => "eu-west-1" } },
                 { "id" => "st-2", "name" => "local", "type" => "LOCAL" }
               ])

      result = storages.list(workspace_id: "ws-1")

      expect(result.map(&:type)).to eq(%w[S3 LOCAL])
      expect(result.first.s3Storage.bucket).to eq("backups")
    end

    it "requires a workspace" do
      expect { storages.list }.to raise_error(DatabasusRuby::ConfigurationError, /workspace_id/)
    end
  end

  describe "#save" do
    it "creates and is aliased as #create and #update" do
      stub_api(:post, "storages", body: { "id" => "st-9", "name" => "offsite" })

      expect(storages.save(name: "offsite", type: "S3", workspaceId: "ws-1").id).to eq("st-9")
      expect(storages.method(:create)).to eq(storages.method(:save))
      expect(storages.method(:update)).to eq(storages.method(:save))
    end

    it "updates when the payload carries an id" do
      stub_api(:post, "storages", body: { "id" => "st-1", "name" => "renamed" })

      storages.save(id: "st-1", name: "renamed", type: "S3", workspaceId: "ws-1")

      expect(WebMock).to have_requested(:post, api_url("storages"))
        .with(body: { "id" => "st-1", "name" => "renamed", "type" => "S3", "workspaceId" => "ws-1" })
    end

    it "fills in the client default workspace" do
      stub_api(:post, "storages", body: {})

      client(workspace_id: "ws-default").storages.save(name: "offsite", type: "LOCAL")

      expect(WebMock).to have_requested(:post, api_url("storages"))
        .with(body: { "name" => "offsite", "type" => "LOCAL", "workspaceId" => "ws-default" })
    end

    it "surfaces the save error the API reports" do
      stub_api(:post, "storages", status: 400, body: { "error" => "bucket does not exist" })

      expect { storages.save(name: "offsite", type: "S3", workspaceId: "ws-1") }
        .to raise_error(DatabasusRuby::BadRequestError, "bucket does not exist")
    end
  end

  describe "#get and #delete" do
    it "fetches one" do
      stub_api(:get, "storages/st-1", body: { "id" => "st-1", "lastSaveError" => "" })

      expect(storages.get("st-1").id).to eq("st-1")
    end

    it "deletes one" do
      stub_api(:delete, "storages/st-1", body: {})

      expect(storages.delete("st-1")).to be(true)
    end
  end

  describe "connection tests" do
    it "tests a saved storage" do
      stub_api(:post, "storages/st-1/test", body: {})

      expect(storages.test("st-1")).to be(true)
    end

    it "tests an unsaved payload" do
      stub_api(:post, "storages/direct-test", body: {})

      storages.direct_test(type: "SFTP", sftpStorage: { "host" => "files.test" })

      expect(WebMock).to have_requested(:post, api_url("storages/direct-test"))
        .with(body: { "type" => "SFTP", "sftpStorage" => { "host" => "files.test" } })
    end

    it "raises when the storage is unreachable" do
      stub_api(:post, "storages/st-1/test", status: 400, body: { "error" => "connection refused" })

      expect { storages.test("st-1") }.to raise_error(DatabasusRuby::BadRequestError, "connection refused")
    end
  end

  describe "#transfer" do
    it "moves the storage to another workspace" do
      stub_api(:post, "storages/st-1/transfer", body: {})

      expect(storages.transfer("st-1", target_workspace_id: "ws-2")).to be(true)
      expect(WebMock).to have_requested(:post, api_url("storages/st-1/transfer"))
        .with(body: { "targetWorkspaceId" => "ws-2" })
    end
  end

  it "exposes the documented types" do
    expect(described_class::TYPES).to include("S3", "LOCAL", "RCLONE", "AZURE_BLOB")
  end
end
