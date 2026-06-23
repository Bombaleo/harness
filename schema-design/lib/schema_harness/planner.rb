require "tsort"
require "set"

module SchemaHarness
  module Planner
    module_function

    def order(stories)
      owner = {} # entity => slug
      stories.each { |s| s[:requirements].each { |r| owner[r["entity"]] = s[:slug] if r["type"] == "entity_exists" } }

      deps = Hash.new { |h, k| h[k] = Set.new } # slug => set of slugs it depends on
      stories.each { |s| deps[s[:slug]] }
      stories.each do |s|
        s[:requirements].each do |r|
          next unless r["type"] == "relationship"
          targets = [r["from"], r["to"]]
          targets.each do |ent|
            dep = owner[ent]
            deps[s[:slug]] << dep if dep && dep != s[:slug]
          end
        end
      end

      cycles = []
      sorted = tsort(deps, cycles)
      prio = sorted.each_with_index.to_h { |slug, i| [slug, i + 1] }

      {
        "branchName" => "schema-design",
        "stories" => stories.sort_by { |s| prio[s[:slug]] }.map { |s|
          { "id" => "us_#{s[:slug]}", "slug" => s[:slug], "title" => s[:title],
            "priority" => prio[s[:slug]],
            "requirementsFile" => "requirements/us_#{s[:slug]}.json", "passes" => false } },
        "cycles" => cycles
      }
    end

    # deterministic topo sort; on cycle, break at lowest-slug node and record it
    def tsort(deps, cycles)
      each_node = ->(&b) { deps.keys.sort.each(&b) }
      each_child = ->(n, &b) { deps[n].to_a.sort.each(&b) }
      begin
        TSort.tsort(each_node, each_child)
      rescue TSort::Cyclic => e
        node = e.message[/\["?([^",\]]+)/, 1] || deps.keys.min
        broken = deps[node].min
        cycles << { "between" => [node, broken].compact }
        deps[node].delete(broken)
        retry
      end
    end
  end
end
