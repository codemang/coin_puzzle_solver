require 'byebug'
require_relative './puzzle_state_builder'
require_relative './puzzle_solver'

def build_state
  puzzle_state_builder = PuzzleStateBuilder.new
  puzzle_state_builder.solve

  byebug
  bad_keys = puzzle_state_builder.global_state.keys.select { |k| k =~ /UNKNOWN/ }
  bad_keys.each { |key| puzzle_state_builder.global_state.delete(key) }

  puzzle_state_builder.global_state.each do |state, data|
    data.each do |obj|
      obj[:max_step] = -1 if obj[:max_step] == Float::INFINITY
    end
  end

  File.open('global_state.json', 'w') { |f| f.puts puzzle_state_builder.global_state.to_json }
  JSON.parse(File.read('global_state.json'))
end

def solve
  PuzzleSolver.new.solve
end

# build_state
solve
3
