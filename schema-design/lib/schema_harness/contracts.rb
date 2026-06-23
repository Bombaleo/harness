module SchemaHarness
  module Contracts
    REQ_ID = /\AREQ-[A-Z0-9]+-\d{3}\z/
    TYPES  = %w[entity_exists attribute relationship constraint state_transition].freeze
    CARD   = %w[one_to_one one_to_many many_to_one many_to_many].freeze
    CKIND  = %w[not_null unique check range foreign_key].freeze

    module_function

    def validate_requirements(h)
      e = []
      %w[story_slug title domain requirements].each { |k| e << "missing #{k}" unless h.key?(k) }
      Array(h["requirements"]).each_with_index do |r, i|
        loc = "requirements[#{i}]"
        e << "#{loc}: id '#{r["id"]}' must match REQ-<DOMAIN>-NNN" unless r["id"].to_s =~ REQ_ID
        e << "#{loc}: unknown type '#{r["type"]}'" unless TYPES.include?(r["type"])
        e << "#{loc}: missing description" if r["description"].to_s.empty?
        case r["type"]
        when "relationship"
          e << "#{loc}: bad cardinality" unless CARD.include?(r["cardinality"])
          %w[from to].each { |k| e << "#{loc}: missing #{k}" if r[k].to_s.empty? }
        when "constraint"
          e << "#{loc}: bad constraint_kind" unless CKIND.include?(r["constraint_kind"])
        when "attribute"
          %w[entity name data_type].each { |k| e << "#{loc}: missing #{k}" if r[k].to_s.empty? }
        when "state_transition"
          e << "#{loc}: needs >=1 transition" if Array(r["transitions"]).empty?
        end
      end
      e
    end

    def validate_prd(h)
      e = []
      e << "missing stories" unless h["stories"].is_a?(Array)
      Array(h["stories"]).each_with_index do |s, i|
        %w[id slug title priority requirementsFile passes].each { |k| e << "stories[#{i}]: missing #{k}" unless s.key?(k) }
        e << "stories[#{i}]: priority must be Integer" unless s["priority"].is_a?(Integer)
      end
      e
    end

    def validate_coverage(h)
      e = []
      e << "missing mappings" unless h["mappings"].is_a?(Array)
      Array(h["mappings"]).each_with_index do |m, i|
        e << "mappings[#{i}]: missing requirement_id" if m["requirement_id"].to_s.empty?
        sb = m["satisfied_by"]
        e << "mappings[#{i}]: empty satisfied_by" if sb.nil? || sb.empty?
      end
      e
    end

    def validate_current_schema(h)
      e = []
      e << "missing tables" unless h["tables"].is_a?(Array)
      Array(h["tables"]).each_with_index do |t, i|
        e << "tables[#{i}]: missing name" if t["name"].to_s.empty?
        e << "tables[#{i}]: missing columns" unless t["columns"].is_a?(Array)
      end
      e
    end
  end
end
