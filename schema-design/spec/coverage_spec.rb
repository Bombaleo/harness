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

  # --- attribute semantics ---
  describe "attribute semantics" do
    let(:areqs) { { "requirements" => [
      { "id" => "REQ-A-001", "type" => "attribute", "entity" => "Vendor", "name" => "status",
        "data_type" => "enum", "nullable" => false }] } }
    let(:acov) { { "mappings" => [
      { "requirement_id" => "REQ-A-001", "satisfied_by" => { "kind" => "column", "table" => "vendors", "name" => "status" } }] } }

    it "passes when column type and nullability match" do
      sch = { "tables" => [{ "name" => "vendors", "columns" => [
        { "name" => "status", "type" => "enum", "null" => false }] }] }
      expect(described_class.check(requirements: areqs, coverage: acov, schema: sch)).to eq([])
    end

    it "fails when column type and nullability mismatch" do
      sch = { "tables" => [{ "name" => "vendors", "columns" => [
        { "name" => "status", "type" => "string", "null" => true }] }] }
      errs = described_class.check(requirements: areqs, coverage: acov, schema: sch)
      expect(errs).to include(match(/REQ-A-001.*type/))
      expect(errs).to include(match(/REQ-A-001.*null/))
    end
  end

  # --- state_transition semantics ---
  describe "state_transition semantics" do
    let(:sreqs) { { "requirements" => [
      { "id" => "REQ-S-001", "type" => "state_transition", "entity" => "JobPosting",
        "states" => ["draft", "published", "closed"] }] } }
    let(:scov) { { "mappings" => [
      { "requirement_id" => "REQ-S-001", "satisfied_by" => { "kind" => "enum", "name" => "posting_status" } }] } }

    it "passes when the enum defines every state" do
      sch = { "enums" => [{ "name" => "posting_status", "values" => ["draft", "published", "closed"] }] }
      expect(described_class.check(requirements: sreqs, coverage: scov, schema: sch)).to eq([])
    end

    it "fails when the enum is missing states" do
      sch = { "enums" => [{ "name" => "posting_status", "values" => ["draft"] }] }
      errs = described_class.check(requirements: sreqs, coverage: scov, schema: sch)
      expect(errs).to include(match(/REQ-S-001.*published.*closed|REQ-S-001.*closed.*published/))
    end

    it "passes via a column carrying an enum_type" do
      cov = { "mappings" => [
        { "requirement_id" => "REQ-S-001", "satisfied_by" => { "kind" => "column", "table" => "job_postings", "name" => "status" } }] }
      sch = { "tables" => [{ "name" => "job_postings", "columns" => [
               { "name" => "status", "type" => "enum", "enum_type" => "posting_status", "null" => false }] }],
             "enums" => [{ "name" => "posting_status", "values" => ["draft", "published", "closed"] }] }
      expect(described_class.check(requirements: sreqs, coverage: cov, schema: sch)).to eq([])
    end
  end

  # --- relationship semantics ---
  describe "relationship semantics" do
    let(:rreqs) { { "requirements" => [
      { "id" => "REQ-R-001", "type" => "relationship", "from" => "Vendor", "to" => "Organization",
        "cardinality" => "many_to_one" }] } }
    let(:rcov) { { "mappings" => [
      { "requirement_id" => "REQ-R-001", "satisfied_by" => { "kind" => "association", "from" => "vendors", "to" => "organizations" } }] } }

    it "passes when association kind matches cardinality" do
      sch = { "associations" => [{ "from" => "vendors", "to" => "organizations", "kind" => "belongs_to" }] }
      expect(described_class.check(requirements: rreqs, coverage: rcov, schema: sch)).to eq([])
    end

    it "fails when association kind contradicts cardinality" do
      sch = { "associations" => [{ "from" => "vendors", "to" => "organizations", "kind" => "has_many" }] }
      errs = described_class.check(requirements: rreqs, coverage: rcov, schema: sch)
      expect(errs).to include(match(/REQ-R-001.*has_many|REQ-R-001.*many_to_one/))
    end
  end

  # --- constraint semantics ---
  describe "constraint semantics" do
    it "passes a foreign_key constraint satisfied by a real FK" do
      creqs = { "requirements" => [
        { "id" => "REQ-C-001", "type" => "constraint", "entity" => "Vendor", "constraint_kind" => "foreign_key" }] }
      ccov = { "mappings" => [
        { "requirement_id" => "REQ-C-001", "satisfied_by" => { "kind" => "constraint", "table" => "vendors", "column" => "organization_id" } }] }
      sch = { "tables" => [{ "name" => "vendors", "checks" => [],
        "foreign_keys" => [{ "column" => "organization_id", "references" => "organizations" }] }] }
      expect(described_class.check(requirements: creqs, coverage: ccov, schema: sch)).to eq([])
    end

    it "fails a foreign_key constraint that is only backed by a CHECK" do
      creqs = { "requirements" => [
        { "id" => "REQ-C-001", "type" => "constraint", "entity" => "Vendor", "constraint_kind" => "foreign_key" }] }
      ccov = { "mappings" => [
        { "requirement_id" => "REQ-C-001", "satisfied_by" => { "kind" => "constraint", "table" => "vendors", "name" => "chk_org", "column" => "organization_id" } }] }
      sch = { "tables" => [{ "name" => "vendors", "foreign_keys" => [],
        "checks" => [{ "name" => "chk_org", "expression" => "organization_id IS NOT NULL" }] }] }
      errs = described_class.check(requirements: creqs, coverage: ccov, schema: sch)
      expect(errs).to include(match(/REQ-C-001.*foreign_key/))
    end
  end
end
