module SchemaHarness
  module Renderer
    module_function

    def to_markdown(schema)
      out = ["# Current Schema\n"]
      Array(schema["enums"]).each { |e| out << "**enum `#{e["name"]}`**: #{Array(e["values"]).join(", ")}\n" }
      Array(schema["tables"]).each do |t|
        out << "## #{t["name"]}\n"
        out << "| column | type | null | pk |"
        out << "|---|---|---|---|"
        Array(t["columns"]).each do |c|
          out << "| #{c["name"]} | #{c["type"]} | #{c["null"] == false ? "NO" : "yes"} | #{c["primary_key"] ? "PK" : ""} |"
        end
        Array(t["foreign_keys"]).each { |fk| out << "\n- FK `#{fk["column"]}` → `#{fk["references"]}` (on_delete: #{fk["on_delete"]})" }
        Array(t["indexes"]).each { |ix| out << "- INDEX `#{ix["name"]}` ON (#{Array(ix["columns"]).join(", ")})#{ix["unique"] ? " UNIQUE" : ""}" }
        Array(t["checks"]).each { |ck| out << "- CHECK `#{ck["name"]}`: `#{ck["expression"]}`" }
        out << ""
      end
      out.join("\n")
    end

    def to_mermaid(schema)
      lines = ["erDiagram"]
      Array(schema["tables"]).each do |t|
        lines << "  #{t["name"]} {"
        Array(t["columns"]).each { |c| lines << "    #{c["type"]} #{c["name"]}" }
        lines << "  }"
      end
      Array(schema["associations"]).each do |a|
        lines << "  #{a["to"]} ||--o{ #{a["from"]} : \"#{a["kind"]}\""
      end
      lines.join("\n")
    end
  end
end
