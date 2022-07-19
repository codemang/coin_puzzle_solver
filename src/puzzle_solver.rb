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

  def initialize
    puzzle_state_builder = PuzzleStateBuilder.new
    puzzle_state_builder.read_from_file
    @puzzle_states = puzzle_state_builder.global_state
  end

  def solve
    coins = Constants::NUM_COINS.times.map { Coin.new(:UNKNOWN) }
    max_num_tries_to_solve_puzzle = 0

    coins.each_with_index do |coin, index|
      puts "\nUpdating coin #{index + 1}"

      puts "-> Making coin heavy"
      coin.make_heavy
      num_steps_when_heavy = calculate_num_steps(coins)
      puts "-> Took #{num_steps_when_heavy} steps to find solution"

      puts "-> Making coin light"
      coin.make_light
      num_steps_when_light = calculate_num_steps(coins)
      puts "-> Took #{num_steps_when_light} steps to find solution"

      coin.make_normal

      max_num_tries_to_solve_puzzle = [max_num_tries_to_solve_puzzle, num_steps_when_heavy, num_steps_when_light].max
    end

    puts "\nMaximum number of steps needed to find solution for any permutation: #{max_num_tries_to_solve_puzzle}"
  end

  def calculate_num_steps(coins)
    coins = coins.map(&:dup)
    steps = 0

    loop do
      break if coins.select(&:not_correct?).length == 1

      new_state_name = state_name(coins.select(&:not_correct?))
      best_move = puzzle_states[new_state_name].min_by { |puzzle_state| puzzle_state.fetch(:max_step) }
      coins_to_weigh = coins.map { |coin| coin } # Copy references to each individual coin over.

      side1 = []
      side2 = []

      best_move[:side1].each do |coin_state|
        index = coins_to_weigh.find_index { |coin| coin.state == coin_state }
        side1 << coins_to_weigh[index]
        coins_to_weigh.delete_at(index)
      end

      best_move[:side2].each do |coin_state|
        index = coins_to_weigh.find_index { |coin| coin.state == coin_state }
        side2 << coins_to_weigh[index]
        coins_to_weigh.delete_at(index)
      end

      Scale.weigh_and_update(coins, side1, side2)
      steps += 1
    end

    steps
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
