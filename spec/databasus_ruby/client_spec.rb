# frozen_string_literal: true

RSpec.describe DatabasusRuby::Client do
  describe "#initialize" do
    it "requires a url" do
      expect { described_class.new(api_key: "k", url: nil) }
        .to raise_error(DatabasusRuby::ConfigurationError, /url is required/)
    end

    it "keeps the base path by ensuring a trailing slash" do
      expect(described_class.new(url: "https://databasus.test/api/v1").url)
        .to eq("https://databasus.test/api/v1/")
    end

    it "does not require api_key, agent_id or workspace_id" do
      instance = described_class.new(url: "https://databasus.test/api/v1/")

      expect(instance.api_key).to be_nil
      expect(instance.agent_id).to be_nil
      expect(instance.workspace_id).to be_nil
    end

    it "never leaks the api key through inspect" do
      expect(client.inspect).to include("[FILTERED]")
      expect(client.inspect).not_to include("test-token")
    end
  end

  describe "endpoint accessors" do
    it "memoizes one endpoint object per domain" do
      instance = client

      expect(instance.databases).to be_a(DatabasusRuby::Databases)
      expect(instance.databases).to be(instance.databases)
      expect(instance.auth).to be_a(DatabasusRuby::Auth)
      expect(instance.backups).to be_a(DatabasusRuby::Backups)
      expect(instance.notifiers).to be_a(DatabasusRuby::Notifiers)
      expect(instance.storages).to be_a(DatabasusRuby::Storages)
      expect(instance.users).to be_a(DatabasusRuby::Users)
      expect(instance.workspaces).to be_a(DatabasusRuby::Workspaces)
    end
  end

  describe "#request" do
    it "resolves paths against the api base and sends the bearer token" do
      stub = stub_api(:get, "users/me", body: { "id" => "u1" })

      client.request(:get, "users/me")

      expect(stub).to have_been_requested
      expect(WebMock).to have_requested(:get, api_url("users/me"))
        .with(headers: { "Authorization" => "Bearer test-token" })
    end

    it "omits the Authorization header when no api key is set" do
      stub_api(:get, "system/version", body: { "version" => "dev" })

      client(api_key: nil).request(:get, "system/version")

      expect(WebMock).to(have_requested(:get, api_url("system/version"))
        .with { |request| !request.headers.key?("Authorization") })
    end

    it "drops nil query parameters" do
      stub_api(:get, "users", query: { "limit" => "10" }, body: { "users" => [] })

      client.request(:get, "users", params: { limit: 10, offset: nil, query: nil })

      expect(WebMock).to have_requested(:get, api_url("users")).with(query: { "limit" => "10" })
    end

    it "serializes array parameters as csv, matching collectionFormat" do
      stub_request(:get, api_url("backups"))
        .with(query: { "database_id" => "db-1", "status" => "COMPLETED,FAILED" })
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      client.request(:get, "backups", params: { database_id: "db-1", status: %w[COMPLETED FAILED] })

      expect(WebMock).to have_requested(:get, api_url("backups"))
        .with(query: { "database_id" => "db-1", "status" => "COMPLETED,FAILED" })
    end

    it "encodes bodies as json" do
      stub_api(:post, "workspaces", body: { "id" => "w1" })

      client.request(:post, "workspaces", body: { "name" => "production" })

      expect(WebMock).to have_requested(:post, api_url("workspaces"))
        .with(body: { "name" => "production" }, headers: { "Content-Type" => "application/json" })
    end
  end

  describe "error mapping" do
    {
      400 => DatabasusRuby::BadRequestError,
      401 => DatabasusRuby::AuthenticationError,
      403 => DatabasusRuby::ForbiddenError,
      404 => DatabasusRuby::NotFoundError,
      409 => DatabasusRuby::ConflictError,
      429 => DatabasusRuby::RateLimitError,
      500 => DatabasusRuby::ServerError,
      503 => DatabasusRuby::ServerError
    }.each do |status, klass|
      it "raises #{klass} on #{status}" do
        stub_api(:get, "users/me", status: status, body: { "error" => "boom" })

        expect { client.users.me }.to raise_error(klass) do |error|
          expect(error.message).to eq("boom")
          expect(error.status).to eq(status)
          expect(error.body).to eq({ "error" => "boom" })
        end
      end
    end

    it "falls back to a generic message when the body carries none" do
      stub_request(:get, api_url("users/me")).to_return(status: 418, body: "")

      expect { client.users.me }.to raise_error(DatabasusRuby::APIError, /returned 418/)
    end

    it "uses a plain-text body as the message, as the stream endpoints send" do
      stub_request(:get, api_url("users/me")).to_return(status: 500, body: "storage unavailable")

      expect { client.users.me }.to raise_error(DatabasusRuby::ServerError, "storage unavailable")
    end
  end

  describe "required-value guards" do
    it "explains which workspace id is missing" do
      expect { client.databases.list }
        .to raise_error(DatabasusRuby::ConfigurationError, /workspace_id is required/)
    end

    it "uses the client default workspace when set" do
      stub_api(:get, "databases", query: { "workspace_id" => "ws-default" }, body: [])

      client(workspace_id: "ws-default").databases.list

      expect(WebMock).to have_requested(:get, api_url("databases"))
        .with(query: { "workspace_id" => "ws-default" })
    end

    it "raises when an agent endpoint is used without an agent id" do
      expect { client.agent_id! }
        .to raise_error(DatabasusRuby::ConfigurationError, /agent_id is required/)
      expect(client(agent_id: "agent-1").agent_id!).to eq("agent-1")
    end
  end
end
