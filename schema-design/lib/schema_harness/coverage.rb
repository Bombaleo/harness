module SchemaHarness
  module Coverage
    module_function

    def check(requirements:, coverage:, schema:)
      e = []
      mapped = {}
      Array(coverage["mappings"]).each do |m|
        id = m["requirement_id"]
        sb = m["satisfied_by"]
        if sb.nil? || sb.empty?
          e << "mapping for #{id} is empty"
        else
          mapped[id] = sb
        end
      end

      Array(requirements["requirements"]).each do |r|
        id = r["id"]
        unless mapped.key?(id)
          e << "requirement #{id} is unmapped"
          next
        end
        e.concat(verify_element(mapped[id], schema, id))
      end
      e
    end

    def verify_element(sb, schema, id)
      tables = Array(schema["tables"])
      enums  = Array(schema["enums"])
      case sb["kind"]
      when "table"
        tables.any? { |t| t["name"] == sb["name"] } ? [] : ["#{id}: table '#{sb["name"]}' not in schema"]
      when "column"
        t = tables.find { |x| x["name"] == sb["table"] }
        return ["#{id}: table '#{sb["table"]}' not in schema"] unless t
        Array(t["columns"]).any? { |c| c["name"] == sb["name"] } ? [] : ["#{id}: column '#{sb["table"]}.#{sb["name"]}' not in schema"]
      when "enum"
        enums.any? { |x| x["name"] == sb["name"] } ? [] : ["#{id}: enum '#{sb["name"]}' not in schema"]
      when "constraint"
        t = tables.find { |x| x["name"] == sb["table"] }
        return ["#{id}: table '#{sb["table"]}' not in schema"] unless t
        Array(t["checks"]).any? { |c| c["name"] == sb["name"] } ? [] : ["#{id}: constraint '#{sb["name"]}' not in schema"]
      when "index"
        t = tables.find { |x| x["name"] == sb["table"] }
        return ["#{id}: table '#{sb["table"]}' not in schema"] unless t
        Array(t["indexes"]).any? { |c| Array(c["columns"]) == Array(sb["columns"]) } ? [] : ["#{id}: index on #{sb["columns"]} not in schema"]
      when "association"
        Array(schema["associations"]).any? { |a| a["from"] == sb["from"] && a["to"] == sb["to"] } ? [] : ["#{id}: association #{sb["from"]}->#{sb["to"]} not in schema"]
      else
        ["#{id}: unknown satisfied_by.kind '#{sb["kind"]}'"]
      end
    end
  end
end
