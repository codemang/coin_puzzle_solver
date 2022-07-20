require 'byebug'
require 'combinatorics'
require 'json'
require 'ostruct'
require_relative './constants'
require_relative './coin'
require_relative './scale'
require_relative './puzzle_state_builder'

class PuzzleSolver
  attr_accessor :puzzle_states

  def initialize(should_read_from_file: false)
    puzzle_state_builder = PuzzleStateBuilder.new
    should_read_from_file ? puzzle_state_builder.read_from_file : puzzle_state_builder.build
    @puzzle_states = puzzle_state_builder.puzzle_states
  end

  def solve
    coins = Constants::NUM_COINS.times.map { Coin.new(:UNKNOWN) }
    max_num_weighs_to_solve_puzzle = 0

    coins.each_with_index do |coin, index|
      puts "\nUpdating coin #{index + 1}"

      puts "-> Making coin heavy"
      coin.make_heavy
      num_weighs_when_heavy = calculate_num_weighs(coins)
      puts "-> Took #{num_weighs_when_heavy} steps to find solution"

      puts "-> Making coin light"
      coin.make_light
      num_weighs_when_light = calculate_num_weighs(coins)
      puts "-> Took #{num_weighs_when_light} steps to find solution"

      coin.make_normal

      max_num_weighs_to_solve_puzzle = [max_num_weighs_to_solve_puzzle, num_weighs_when_heavy, num_weighs_when_light].max
    end

    puts "\nMaximum number of steps needed to find solution for any permutation: #{max_num_weighs_to_solve_puzzle}"
  end

  def calculate_num_weighs(orig_coins)
    # We don't want to update the original coins, so we duplicate them.
    coins = orig_coins.map(&:dup)
    num_weighs = 0

    loop do
      break if coins.select(&:not_correct?).length == 1

      new_state_name = state_name(coins.select(&:not_correct?))

      best_move = puzzle_states[new_state_name].min_by do |puzzle_state|
        puzzle_state.fetch(:max_num_weighs_to_solve)
      end

      # Copy references to each individual coin over. We do this because we
      # need a copy of all original coins in one array to weigh them, but we
      # want to use the following variable to remove coins as we deal with
      # them.
      coins_not_on_scale = coins.map { |coin| coin }

      side1 = []
      side2 = []

      best_move[:side1].each do |coin_state|
        index = coins_not_on_scale.find_index { |coin| coin.state == coin_state }
        side1 << coins_not_on_scale[index]
        coins_not_on_scale.delete_at(index)
      end

      best_move[:side2].each do |coin_state|
        index = coins_not_on_scale.find_index { |coin| coin.state == coin_state }
        side2 << coins_not_on_scale[index]
        coins_not_on_scale.delete_at(index)
      end

      Scale.weigh_and_update(coins, side1, side2)

      num_weighs += 1
    end

    num_weighs
  end

  def state_name(bad_coins)
    state_count = bad_coins.each_with_object({}) do |bad_coin, memo|
      memo[bad_coin.state] ||= 0
      memo[bad_coin.state] += 1
    end

    bad_coins.map(&:state).uniq.sort.map do |bad_coin_state|
      "#{bad_coin_state}-#{state_count[bad_coin_state]}"
    end.join(':')
  end
end
