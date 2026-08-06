# frozen_string_literal: true

RSpec.describe DatabasusRuby::Notifiers do
  subject(:notifiers) { client.notifiers }

  describe "#list" do
    it "reads the bare-array response" do
      stub_api(:get, "notifiers", query: { "workspace_id" => "ws-1" }, body: [
                 { "id" => "n-1", "name" => "ops", "notifierType" => "SLACK",
                   "slackNotifier" => { "channelId" => "C123" } },
                 { "id" => "n-2", "name" => "mail", "notifierType" => "EMAIL" }
               ])

      result = notifiers.list(workspace_id: "ws-1")

      expect(result.map(&:notifierType)).to eq(%w[SLACK EMAIL])
      expect(result.first.slackNotifier.channelId).to eq("C123")
    end

    it "requires a workspace" do
      expect { notifiers.list }.to raise_error(DatabasusRuby::ConfigurationError, /workspace_id/)
    end
  end

  describe "#save" do
    it "creates and is aliased as #create and #update" do
      stub_api(:post, "notifiers", body: { "id" => "n-9", "name" => "ops" })

      expect(notifiers.save(name: "ops", notifierType: "SLACK", workspaceId: "ws-1").id).to eq("n-9")
      expect(notifiers.method(:create)).to eq(notifiers.method(:save))
      expect(notifiers.method(:update)).to eq(notifiers.method(:save))
    end

    it "fills in the client default workspace" do
      stub_api(:post, "notifiers", body: {})

      client(workspace_id: "ws-default").notifiers.save(name: "ops", notifierType: "EMAIL")

      expect(WebMock).to have_requested(:post, api_url("notifiers"))
        .with(body: { "name" => "ops", "notifierType" => "EMAIL", "workspaceId" => "ws-default" })
    end
  end

  describe "#get and #delete" do
    it "fetches one" do
      stub_api(:get, "notifiers/n-1", body: { "id" => "n-1", "lastSendError" => "" })

      expect(notifiers.get("n-1").id).to eq("n-1")
    end

    it "deletes one" do
      stub_api(:delete, "notifiers/n-1", body: {})

      expect(notifiers.delete("n-1")).to be(true)
    end
  end

  describe "test notifications" do
    it "sends through a saved notifier" do
      stub_api(:post, "notifiers/n-1/test", body: {})

      expect(notifiers.test("n-1")).to be(true)
    end

    it "sends through an unsaved payload" do
      stub_api(:post, "notifiers/direct-test", body: {})

      notifiers.direct_test(notifierType: "WEBHOOK", webhookNotifier: { "url" => "https://hooks.test" })

      expect(WebMock).to have_requested(:post, api_url("notifiers/direct-test"))
        .with(body: { "notifierType" => "WEBHOOK", "webhookNotifier" => { "url" => "https://hooks.test" } })
    end

    it "raises when delivery fails" do
      stub_api(:post, "notifiers/n-1/test", status: 400, body: { "error" => "channel_not_found" })

      expect { notifiers.test("n-1") }.to raise_error(DatabasusRuby::BadRequestError, "channel_not_found")
    end
  end

  describe "#transfer" do
    it "moves the notifier to another workspace" do
      stub_api(:post, "notifiers/n-1/transfer", body: {})

      expect(notifiers.transfer("n-1", target_workspace_id: "ws-2")).to be(true)
      expect(WebMock).to have_requested(:post, api_url("notifiers/n-1/transfer"))
        .with(body: { "targetWorkspaceId" => "ws-2" })
    end
  end

  it "exposes the documented types" do
    expect(described_class::TYPES).to include("EMAIL", "SLACK", "TEAMS")
    expect(described_class::NOTIFICATION_TYPES).to include("ALL", "BACKUP_FAILED")
  end
end
