# frozen_string_literal: true

RSpec.describe DatabasusRuby::Notifiers do
  subject(:notifiers) { client.notifiers }

  let(:notifier) do
    { "id" => "n-1", "workspaceId" => "ws-1", "name" => "ops",
      "settings" => { "type" => "SLACK", "channelId" => "C123" } }
  end

  describe "#list" do
    it "reads the cursor page for the workspace" do
      stub_api(:get, "notifiers", query: { "workspaceId" => "ws-1", "limit" => "10" },
                                  body: { "items" => [notifier], "nextCursor" => "cur-2" })

      result = notifiers.list(workspace_id: "ws-1", limit: 10)

      expect(result.first.settings.type).to eq("SLACK")
      expect(result.next_cursor).to eq("cur-2")
    end

    it "requires a workspace" do
      expect { notifiers.list }.to raise_error(DatabasusRuby::ConfigurationError, /workspace_id is required/)
    end
  end

  describe "#get" do
    it "reads one notifier" do
      stub_api(:get, "notifiers/n-1", body: notifier)

      expect(notifiers.get("n-1").name).to eq("ops")
      expect(notifiers.find("n-1").id).to eq("n-1")
    end
  end

  describe "#create" do
    it "posts to /notifiers with the client default workspace" do
      stub_api(:post, "notifiers", status: 201, body: notifier)

      instance = client(workspace_id: "ws-1")
      created = instance.notifiers.create(name: "ops", settings: { type: "SLACK", channelId: "C123" })

      expect(created.id).to eq("n-1")
      expect(WebMock).to have_requested(:post, api_url("notifiers")).with(
        body: { "workspaceId" => "ws-1", "name" => "ops", "settings" => { "type" => "SLACK", "channelId" => "C123" } }
      )
    end
  end

  describe "#update" do
    it "puts name and settings to /notifiers/{id}" do
      stub_api(:put, "notifiers/n-1", body: notifier.merge("name" => "oncall"))

      expect(notifiers.update("n-1", name: "oncall", settings: { type: "SLACK" }).name).to eq("oncall")
      expect(WebMock).to have_requested(:put, api_url("notifiers/n-1"))
        .with(body: { "name" => "oncall", "settings" => { "type" => "SLACK" } })
    end
  end

  describe "#delete, #test and #transfer" do
    it "deletes" do
      stub_request(:delete, api_url("notifiers/n-1")).to_return(status: 204, body: "")

      expect(notifiers.delete("n-1")).to be(true)
    end

    it "sends a test notification" do
      stub_request(:post, api_url("notifiers/n-1/test")).to_return(status: 204, body: "")

      expect(notifiers.test("n-1")).to be_a(DatabasusRuby::Object)
      expect(WebMock).to have_requested(:post, api_url("notifiers/n-1/test"))
    end

    it "surfaces a failed test as a problem" do
      stub_api(:post, "notifiers/n-1/test", status: 400, body: {
                 "title" => "Bad Request", "status" => 400, "detail" => "slack answered channel_not_found",
                 "code" => "notifier_test_failed"
               })

      expect { notifiers.test("n-1") }
        .to raise_error(DatabasusRuby::BadRequestError, "slack answered channel_not_found")
    end

    it "transfers to another workspace" do
      stub_api(:post, "notifiers/n-1/transfer", body: notifier.merge("workspaceId" => "ws-2"))

      expect(notifiers.transfer("n-1", target_workspace_id: "ws-2").workspace_id).to eq("ws-2")
      expect(WebMock).to have_requested(:post, api_url("notifiers/n-1/transfer"))
        .with(body: { "targetWorkspaceId" => "ws-2" })
    end
  end

  it "exposes the documented types" do
    expect(described_class::TYPES).to include("EMAIL", "SLACK", "WEBHOOK")
  end
end
