# frozen_string_literal: true

require "stringio"

RSpec.describe DatabasusRuby::Client do
  describe "#initialize" do
    it "requires a url" do
      expect { described_class.new(api_key: "k", url: nil) }
        .to raise_error(DatabasusRuby::ConfigurationError, /url is required/)
      expect { described_class.new(api_key: "k", url: "") }
        .to raise_error(DatabasusRuby::ConfigurationError, /url is required/)
    end

    it "keeps the base path by ensuring a trailing slash" do
      expect(described_class.new(url: "https://databasus.test/api/v1").url)
        .to eq("https://databasus.test/api/v1/")
    end

    it "does not require api_key or workspace_id" do
      instance = described_class.new(url: "https://databasus.test/api/v1/")

      expect(instance.api_key).to be_nil
      expect(instance.workspace_id).to be_nil
    end

    it "never leaks the api key through inspect" do
      expect(client.inspect).to include("[FILTERED]")
      expect(client.inspect).not_to include("test-token")
      expect(client(api_key: nil).inspect).to include("api_key=nil")
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
      expect(instance.restores).to be_a(DatabasusRuby::Restores)
      expect(instance.storages).to be_a(DatabasusRuby::Storages)
      expect(instance.users).to be_a(DatabasusRuby::Users)
      expect(instance.workspaces).to be_a(DatabasusRuby::Workspaces)
    end
  end

  describe "#request" do
    it "resolves paths against the api base and sends the bearer token" do
      stub = stub_api(:get, "users/u1", body: { "id" => "u1" })

      client.request(:get, "users/u1")

      expect(stub).to have_been_requested
      expect(WebMock).to have_requested(:get, api_url("users/u1"))
        .with(headers: { "Authorization" => "Bearer test-token" })
    end

    it "omits the Authorization header when no api key is set" do
      stub_api(:get, "system/version", body: { "version" => "3.65.0" })

      client(api_key: nil).request(:get, "system/version")

      expect(WebMock).to(have_requested(:get, api_url("system/version"))
        .with { |request| !request.headers.key?("Authorization") })
    end

    it "drops nil query parameters" do
      stub_api(:get, "users", query: { "limit" => "10" }, body: { "items" => [] })

      client.request(:get, "users", params: { limit: 10, after: nil, query: nil })

      expect(WebMock).to have_requested(:get, api_url("users")).with(query: { "limit" => "10" })
    end

    it "repeats the key for array parameters (form style, explode)", :flat_query do
      stub_request(:get, "#{api_url("logical-backups")}?databaseId=db-1&status=COMPLETED&status=FAILED")
        .to_return(status: 200, body: '{"items":[]}', headers: { "Content-Type" => "application/json" })

      client.request(:get, "logical-backups", params: { databaseId: "db-1", status: %w[COMPLETED FAILED] })

      expect(WebMock).to have_requested(:get,
                                        "#{api_url("logical-backups")}?databaseId=db-1&status=COMPLETED&status=FAILED")
      expect(WebMock).not_to have_requested(:get, /status%5B%5D|status\[\]/)
    end

    it "encodes bodies as json" do
      stub_api(:post, "workspaces", status: 201, body: { "id" => "w1" })

      client.request(:post, "workspaces", body: { "name" => "production" })

      expect(WebMock).to have_requested(:post, api_url("workspaces"))
        .with(body: { "name" => "production" }, headers: { "Content-Type" => "application/json" })
    end

    it "decodes application/problem+json bodies" do
      stub_request(:get, api_url("users/u1")).to_return(
        status: 404,
        body: JSON.generate({ "title" => "Not Found", "status" => 404, "detail" => "no such user",
                              "code" => "not_found" }),
        headers: { "Content-Type" => "application/problem+json" }
      )

      expect { client.request(:get, "users/u1") }.to raise_error(DatabasusRuby::NotFoundError) do |error|
        expect(error.body).to be_a(Hash)
        expect(error.code).to eq("not_found")
      end
    end
  end

  describe "#stream" do
    it "writes the body into the io and returns the byte count" do
      stub_request(:get, api_url("logical-backups/b1/file"))
        .with(query: { "token" => "tok-1" })
        .to_return(status: 200, body: "\x1f\x8bbinary".b, headers: { "Content-Type" => "application/octet-stream" })
      io = StringIO.new(+"".b)

      written = client.stream("logical-backups/b1/file", io: io, params: { token: "tok-1" })

      expect(written).to eq(8)
      expect(io.string).to eq("\x1f\x8bbinary".b)
      expect(WebMock).to have_requested(:get, api_url("logical-backups/b1/file"))
        .with(query: { "token" => "tok-1" }, headers: { "Authorization" => "Bearer test-token" })
    end

    it "raises the matching error with the problem decoded and leaves the io untouched" do
      stub_request(:get, api_url("logical-backups/b1/file")).with(query: { "token" => "tok-1" }).to_return(
        status: 409,
        body: JSON.generate({
                              "type" => "about:blank", "title" => "Conflict", "status" => 409,
                              "detail" => "the backup is still in progress", "code" => "backup_not_completed"
                            }),
        headers: { "Content-Type" => "application/problem+json" }
      )
      io = StringIO.new(+"")

      expect { client.stream("logical-backups/b1/file", io: io, params: { token: "tok-1" }) }
        .to raise_error(DatabasusRuby::ConflictError) do |error|
          expect(error.message).to eq("the backup is still in progress")
          expect(error.code).to eq("backup_not_completed")
          expect(error.status).to eq(409)
          expect(error.body).to include("title" => "Conflict")
        end
      expect(io.string).to be_empty
    end

    it "keeps a non-json error body as text" do
      stub_request(:get, api_url("logical-backups/b1/file")).to_return(status: 502, body: "bad gateway")

      expect { client.stream("logical-backups/b1/file", io: StringIO.new) }
        .to raise_error(DatabasusRuby::ServerError, "bad gateway")
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
        problem = { "type" => "about:blank", "title" => "Boom", "status" => status, "detail" => "boom",
                    "code" => "boom_code" }
        stub_api(:get, "users/u1", status: status, body: problem)

        expect { client.users.get("u1") }.to raise_error(klass) do |error|
          expect(error.message).to eq("boom")
          expect(error.status).to eq(status)
          expect(error.code).to eq("boom_code")
          expect(error.body).to eq(problem)
        end
      end
    end

    it "takes the message from detail before title" do
      stub_api(:get, "users/u1", status: 400,
                                 body: { "title" => "Bad Request", "detail" => "limit must be at most 100" })

      expect { client.users.get("u1") }.to raise_error(DatabasusRuby::BadRequestError, "limit must be at most 100")
    end

    it "appends the field errors of a validation problem" do
      stub_api(:get, "users/u1", status: 400, body: {
                 "detail" => "the request breaks a validation rule", "code" => "invalid_request",
                 "errors" => [{ "field" => "storageId", "detail" => "is required" }]
               })

      expect { client.users.get("u1") }
        .to raise_error(DatabasusRuby::BadRequestError, "the request breaks a validation rule — storageId: is required")
    end

    it "falls back to the title when there is no detail" do
      stub_api(:get, "users/u1", status: 403, body: { "title" => "Forbidden", "status" => 403 })

      expect { client.users.get("u1") }.to raise_error(DatabasusRuby::ForbiddenError, "Forbidden") do |error|
        expect(error.code).to be_nil
      end
    end

    it "maps unknown statuses onto the generic APIError" do
      stub_api(:get, "users/u1", status: 410, body: { "detail" => "gone", "code" => "pending_sign_in_not_usable" })

      expect { client.users.get("u1") }.to raise_error(DatabasusRuby::APIError, "gone") do |error|
        expect(error.class).to eq(DatabasusRuby::APIError)
        expect(error.code).to eq("pending_sign_in_not_usable")
      end
    end

    it "falls back to a generic message when the body carries none" do
      stub_request(:get, api_url("users/u1")).to_return(status: 418, body: "")

      expect { client.users.get("u1") }.to raise_error(DatabasusRuby::APIError, /returned 418/)
    end

    it "uses a plain-text body as the message" do
      stub_request(:get, api_url("users/u1")).to_return(status: 500, body: "storage unavailable")

      expect { client.users.get("u1") }.to raise_error(DatabasusRuby::ServerError, "storage unavailable")
    end
  end

  describe "required-value guards" do
    it "explains which workspace id is missing" do
      expect { client.databases.list }
        .to raise_error(DatabasusRuby::ConfigurationError, /workspace_id is required/)
    end

    it "uses the client default workspace when set" do
      stub_api(:get, "databases", query: { "workspaceId" => "ws-default" }, body: { "items" => [] })

      client(workspace_id: "ws-default").databases.list

      expect(WebMock).to have_requested(:get, api_url("databases"))
        .with(query: { "workspaceId" => "ws-default" })
    end

    it "#workspace_id! answers the default" do
      expect(client(workspace_id: "ws-1").workspace_id!).to eq("ws-1")
    end
  end
end
