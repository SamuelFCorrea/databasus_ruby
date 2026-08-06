# frozen_string_literal: true

module DatabasusRuby
  # A payload that remembers the client it came from, so the record can reach
  # the endpoints related to it:
  #
  #   client.databases.get(id).backups(status: "COMPLETED")
  #
  # Plain Object stays the wrapper for nested fields and for responses that
  # have nothing hanging off them; Record exists only for the payloads whose
  # domain has related endpoints.
  class Record < Object
    attr_reader :client

    def initialize(client, attributes = {})
      @client = client
      super(attributes)
    end

    private

    # Related endpoints address the record by id, and the API omits empty
    # fields, so a record built from a partial payload has to say so rather
    # than sending a request with a nil id.
    def id!
      value = self["id"]
      raise Error, "this #{self.class.name} has no id" if value.nil? || value.to_s.empty?

      value
    end
  end
end
