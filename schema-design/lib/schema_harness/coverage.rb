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
        e.concat(verify_element(mapped[id], schema, id, r))
      end
      e
    end

    # cardinality -> acceptable association kinds
    CARDINALITY_KINDS = {
      "many_to_one"  => ["belongs_to"],
      "one_to_many"  => ["has_many"],
      "many_to_many" => ["has_and_belongs_to_many"],
      "one_to_one"   => ["belongs_to", "has_one"]
    }.freeze

    def verify_element(sb, schema, id, req = {})
      tables = Array(schema["tables"])
      enums  = Array(schema["enums"])
      case sb["kind"]
      when "table"
        return ["#{id}: table '#{sb["name"]}' not in schema"] unless tables.any? { |t| t["name"] == sb["name"] }
        []
      when "column"
        t = tables.find { |x| x["name"] == sb["table"] }
        return ["#{id}: table '#{sb["table"]}' not in schema"] unless t
        col = Array(t["columns"]).find { |c| c["name"] == sb["name"] }
        return ["#{id}: column '#{sb["table"]}.#{sb["name"]}' not in schema"] unless col
        if req["type"] == "state_transition"
          verify_state_transition_column(col, schema, id, req)
        else
          verify_column_semantics(col, schema, id, req)
        end
      when "enum"
        return ["#{id}: enum '#{sb["name"]}' not in schema"] unless enums.any? { |x| x["name"] == sb["name"] }
        verify_state_transition(enums.find { |x| x["name"] == sb["name"] }, id, req)
      when "constraint"
        verify_constraint(sb, tables, id, req)
      when "index"
        t = tables.find { |x| x["name"] == sb["table"] }
        return ["#{id}: table '#{sb["table"]}' not in schema"] unless t
        Array(t["indexes"]).any? { |c| Array(c["columns"]) == Array(sb["columns"]) } ? [] : ["#{id}: index on #{sb["columns"]} not in schema"]
      when "association"
        assoc = Array(schema["associations"]).find { |a| a["from"] == sb["from"] && a["to"] == sb["to"] }
        return ["#{id}: association #{sb["from"]}->#{sb["to"]} not in schema"] unless assoc
        verify_relationship(assoc, sb, id, req)
      else
        ["#{id}: unknown satisfied_by.kind '#{sb["kind"]}'"]
      end
    end

    # attribute: type + nullability must match the requirement
    def verify_column_semantics(col, schema, id, req)
      e = []
      return e unless req["type"] == "attribute"
      if req["data_type"] && col["type"] && col["type"] != req["data_type"]
        e << "#{id}: column '#{col["name"]}' type '#{col["type"]}' does not match required data_type '#{req["data_type"]}'"
      end
      if req.key?("nullable") && col.key?("null") && col["null"] != req["nullable"]
        e << "#{id}: column '#{col["name"]}' null=#{col["null"]} does not match required nullable=#{req["nullable"]}"
      end
      e
    end

    # state_transition mapped to a column: resolve its enum and check states
    def verify_state_transition_column(col, schema, id, req)
      return [] unless req["type"] == "state_transition"
      enum_name = col["enum_type"]
      enum = enum_name && Array(schema["enums"]).find { |x| x["name"] == enum_name }
      unless enum
        return ["#{id}: column '#{col["name"]}' has no enum to represent states #{Array(req["states"]).inspect}"]
      end
      verify_state_transition(enum, id, req)
    end

    # state_transition: enum values must include every required state
    def verify_state_transition(enum, id, req)
      return [] unless req["type"] == "state_transition"
      unless enum
        return ["#{id}: no enum found to represent states #{Array(req["states"]).inspect}"]
      end
      missing = Array(req["states"]) - Array(enum["values"])
      return [] if missing.empty?
      ["#{id}: enum '#{enum["name"]}' is missing states #{missing.inspect}"]
    end

    # relationship: association kind must be consistent with cardinality
    def verify_relationship(assoc, sb, id, req)
      return [] unless req["type"] == "relationship"
      card = req["cardinality"]
      acceptable = CARDINALITY_KINDS[card]
      return [] if acceptable.nil? # unknown cardinality vocab: don't over-flag
      return [] if acceptable.include?(assoc["kind"])
      ["#{id}: association #{sb["from"]}->#{sb["to"]} kind '#{assoc["kind"]}' is inconsistent with cardinality '#{card}'"]
    end

    # constraint: the RIGHT KIND of constraint must exist, per req["constraint_kind"]
    def verify_constraint(sb, tables, id, req)
      t = tables.find { |x| x["name"] == sb["table"] }
      return ["#{id}: table '#{sb["table"]}' not in schema"] unless t
      kind = req["constraint_kind"]
      case kind
      when "foreign_key"
        fks = Array(t["foreign_keys"])
        col = sb["column"]
        ok = col ? fks.any? { |f| f["column"] == col } : !fks.empty?
        ok ? [] : ["#{id}: no foreign_key constraint#{col ? " on '#{col}'" : ""} on table '#{sb["table"]}'"]
      when "unique"
        idx = Array(t["indexes"])
        cols = sb["columns"]
        ok = idx.any? { |i| i["unique"] && (cols.nil? || Array(i["columns"]) == Array(cols)) }
        ok ? [] : ["#{id}: no unique index#{cols ? " on #{Array(cols).inspect}" : ""} on table '#{sb["table"]}'"]
      when "not_null"
        name = sb["name"] || sb["column"]
        col = Array(t["columns"]).find { |c| c["name"] == name }
        return ["#{id}: column '#{sb["table"]}.#{name}' not in schema"] unless col
        col["null"] == false ? [] : ["#{id}: not_null constraint requires column '#{name}' to be null=false"]
      else # "check", "range", or unspecified: a named CHECK entry
        Array(t["checks"]).any? { |c| c["name"] == sb["name"] } ? [] : ["#{id}: constraint '#{sb["name"]}' not in schema"]
      end
    end
  end
end
