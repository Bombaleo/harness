# spec/coverage_spec.rb
require_relative "../lib/schema_harness/coverage"

RSpec.describe SchemaHarness::Coverage do
  let(:reqs) { { "requirements" => [
    { "id" => "REQ-V-001", "type" => "entity_exists", "entity" => "Vendor" },
    { "id" => "REQ-V-002", "type" => "attribute", "entity" => "Vendor", "name" => "status" }] } }
  let(:schema) { { "tables" => [
    { "name" => "vendors", "columns" => [{ "name" => "id" }, { "name" => "status" }] }] } }

  it "passes when every requirement maps to a real schema element" do
    cov = { "mappings" => [
      { "requirement_id" => "REQ-V-001", "satisfied_by" => { "kind" => "table", "name" => "vendors" } },
      { "requirement_id" => "REQ-V-002", "satisfied_by" => { "kind" => "column", "table" => "vendors", "name" => "status" } }] }
    expect(described_class.check(requirements: reqs, coverage: cov, schema: schema)).to eq([])
  end

  it "fails on an unmapped requirement" do
    cov = { "mappings" => [{ "requirement_id" => "REQ-V-001", "satisfied_by" => { "kind" => "table", "name" => "vendors" } }] }
    expect(described_class.check(requirements: reqs, coverage: cov, schema: schema)).to include(match(/REQ-V-002/))
  end

  it "fails on a mapping that points at a non-existent column" do
    cov = { "mappings" => [
      { "requirement_id" => "REQ-V-001", "satisfied_by" => { "kind" => "table", "name" => "vendors" } },
      { "requirement_id" => "REQ-V-002", "satisfied_by" => { "kind" => "column", "table" => "vendors", "name" => "ghost" } }] }
    expect(described_class.check(requirements: reqs, coverage: cov, schema: schema)).to include(match(/ghost/))
  end
end
