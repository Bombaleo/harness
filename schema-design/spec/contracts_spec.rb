# spec/contracts_spec.rb
require "json"
require_relative "../lib/schema_harness/contracts"

RSpec.describe SchemaHarness::Contracts do
  def fixture(name) = JSON.parse(File.read("spec/fixtures/#{name}"))

  it "accepts a well-formed requirements file" do
    expect(described_class.validate_requirements(fixture("requirements_valid.json"))).to eq([])
  end

  it "rejects a requirement whose id violates the REQ-<DOMAIN>-NNN pattern" do
    errors = described_class.validate_requirements(fixture("requirements_bad_id.json"))
    expect(errors).to include(match(/REQ-/))
  end

  it "rejects an unknown requirement type" do
    h = { "story_slug" => "x", "title" => "x", "domain" => "X",
          "requirements" => [{ "id" => "REQ-X-001", "type" => "teleport", "description" => "d" }] }
    expect(described_class.validate_requirements(h)).to include(match(/type/))
  end

  describe ".validate_prd" do
    it "accepts a well-formed prd" do
      h = { "branchName" => "schema-design",
            "stories" => [{ "id" => "us_vendor-onboarding", "slug" => "vendor-onboarding",
                            "title" => "Vendor onboarding", "priority" => 1,
                            "requirementsFile" => "requirements/us_vendor-onboarding.json",
                            "passes" => false }] }
      expect(described_class.validate_prd(h)).to eq([])
    end

    it "rejects a non-Integer priority" do
      h = { "stories" => [{ "id" => "us_x", "slug" => "x", "title" => "X", "priority" => "1",
                            "requirementsFile" => "requirements/us_x.json", "passes" => false }] }
      expect(described_class.validate_prd(h)).to include(match(/priority/))
    end
  end

  describe ".validate_coverage" do
    it "accepts a well-formed coverage matrix" do
      h = { "story_slug" => "vendor-onboarding",
            "mappings" => [{ "requirement_id" => "REQ-V-001",
                             "satisfied_by" => { "kind" => "table", "name" => "x" } }] }
      expect(described_class.validate_coverage(h)).to eq([])
    end

    it "rejects a mapping with an empty satisfied_by" do
      h = { "mappings" => [{ "requirement_id" => "REQ-V-001", "satisfied_by" => {} }] }
      expect(described_class.validate_coverage(h)).to include(match(/satisfied_by/))
    end
  end

  describe ".validate_current_schema" do
    it "accepts a well-formed schema" do
      h = { "tables" => [{ "name" => "vendors", "columns" => [] }] }
      expect(described_class.validate_current_schema(h)).to eq([])
    end

    it "rejects a table missing a name" do
      h = { "tables" => [{ "columns" => [] }] }
      expect(described_class.validate_current_schema(h)).to include(match(/name/))
    end
  end
end
