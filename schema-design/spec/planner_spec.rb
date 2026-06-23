require_relative "../lib/schema_harness/planner"

RSpec.describe SchemaHarness::Planner do
  let(:vendors) { { slug: "vendors", title: "Vendors",
    requirements: [{ "type" => "entity_exists", "entity" => "Vendor" }] } }
  let(:postings) { { slug: "postings", title: "Postings", requirements: [
    { "type" => "entity_exists", "entity" => "JobPosting" },
    { "type" => "relationship", "from" => "JobPosting", "to" => "Vendor", "cardinality" => "many_to_one" }] } }

  it "orders a dependency before its dependent" do
    prd = described_class.order([postings, vendors])
    pr = prd["stories"].to_h { |s| [s["slug"], s["priority"]] }
    expect(pr["vendors"]).to be < pr["postings"]
  end

  it "records a cycle instead of raising" do
    a = { slug: "a", title: "A", requirements: [
      { "type" => "entity_exists", "entity" => "A" },
      { "type" => "relationship", "from" => "A", "to" => "B", "cardinality" => "many_to_one" }] }
    b = { slug: "b", title: "B", requirements: [
      { "type" => "entity_exists", "entity" => "B" },
      { "type" => "relationship", "from" => "B", "to" => "A", "cardinality" => "many_to_one" }] }
    prd = described_class.order([a, b])
    expect(prd["cycles"]).not_to be_empty
    expect(prd["stories"].map { |s| s["slug"] }).to contain_exactly("a", "b")
  end
end
