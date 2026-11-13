# frozen_string_literal: true

RSpec.describe DatabasusRuby do
  it "has a version number" do
    expect(DatabasusRuby::VERSION).not_to be nil
  end

  it "autoloads every endpoint domain" do
    expect(described_class::Auth).to be < described_class::Object
    expect(described_class::Backups).to be < described_class::Object
    expect(described_class::Databases).to be < described_class::Object
    expect(described_class::Notifiers).to be < described_class::Object
    expect(described_class::Restores).to be < described_class::Object
    expect(described_class::Storages).to be < described_class::Object
    expect(described_class::Users).to be < described_class::Object
    expect(described_class::Workspaces).to be < described_class::Object
  end

  it "autoloads the error hierarchy" do
    expect(described_class::AuthenticationError).to be < described_class::APIError
    expect(described_class::APIError).to be < described_class::Error
    expect(described_class::ConfigurationError).to be < described_class::Error
    expect(described_class::SignInCodeRequiredError).to be < described_class::Error
  end
end
