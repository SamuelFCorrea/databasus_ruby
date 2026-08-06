# frozen_string_literal: true

require "databasus_ruby"
require "webmock/rspec"

module ClientHelpers
  BASE_URL = "https://databasus.test/api/v1/"

  def client(**overrides)
    DatabasusRuby::Client.new(api_key: "test-token", url: BASE_URL, **overrides)
  end

  def api_url(path)
    "#{BASE_URL}#{path}"
  end

  # Stubs a JSON response for `path` relative to the API base.
  def stub_api(method, path, status: 200, body: nil, request_body: nil, query: nil)
    stub = stub_request(method, api_url(path))
    stub = stub.with(query: query) if query
    stub = stub.with(body: request_body) if request_body
    stub.to_return(
      status: status,
      body: body.nil? ? "" : JSON.generate(body),
      headers: { "Content-Type" => "application/json" }
    )
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include ClientHelpers
end
