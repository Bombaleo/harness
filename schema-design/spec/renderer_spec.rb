# spec/renderer_spec.rb
require_relative "../lib/schema_harness/renderer"

RSpec.describe SchemaHarness::Renderer do
  let(:schema) { { "tables" => [
    { "name" => "vendors", "columns" => [
      { "name" => "id", "type" => "uuid", "null" => false, "primary_key" => true },
      { "name" => "status", "type" => "enum", "null" => false }],
      "foreign_keys" => [{ "column" => "org_id", "references" => "organizations", "on_delete" => "restrict" }],
      "indexes" => [{ "name" => "idx_vendors_status", "columns" => ["status"], "unique" => false }] }],
    "associations" => [{ "from" => "vendors", "to" => "organizations", "kind" => "belongs_to" }] } }

  it "renders a markdown table section" do
    md = described_class.to_markdown(schema)
    expect(md).to include("vendors").and include("status").and include("uuid")
  end

  it "renders indexes in the markdown" do
    md = described_class.to_markdown(schema)
    expect(md).to include("idx_vendors_status").and include("status")
  end

  it "renders a mermaid erDiagram with the relationship" do
    mmd = described_class.to_mermaid(schema)
    expect(mmd).to start_with("erDiagram")
    expect(mmd).to include("vendors").and include("organizations")
  end
end
