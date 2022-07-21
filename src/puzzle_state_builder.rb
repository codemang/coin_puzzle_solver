require 'byebug'
require 'combinatorics'
require 'json'
require 'ostruct'
require_relative './coin'
require_relative './scale'
require_relative './constants'
require_relative './array'
require_relative './logger'

class PuzzleStateBuilder
  # When weighing coins, it's possible that you learn nothing about your coins,
  # leaving you in the same state you started in. We therefore assign that
  # approach the maximum score possible.
  MAX_NUM_WEIGHS_TO_SOLVE = 999

  NUM_INCORRECT_COINS_TO_CONSIDER = 6

  DEFAULT_OUTPUT_FILE_NAME = 'tmp/puzzle_states.json'.freeze

  attr_accessor :puzzle_states

  def initialize
    @puzzle_states = {}
  end

  def build
    Logger.log("Starting process to calculate all possible puzzle states and their distance from the final solution.")
    create_puzzle_states_for_low_coins
    create_puzzle_states_for_high_coins
    create_puzzle_states_for_low_high_coin_combos
    create_puzzle_state_for_unknown_coins
  end

  def save_to_file(filename = DEFAULT_OUTPUT_FILE_NAME)
    File.open(filename, 'w') { |f| f.puts puzzle_states.to_json }
  end

  def read_from_file(filename = DEFAULT_OUTPUT_FILE_NAME)
    begin
      puzzle_states_from_file = JSON.parse(File.read(filename))
    rescue Errno::ENOENT
      puts "ERROR: Could not find the '#{filename}' file when trying to read puzzle states. Please run 'bin/save_puzzle_states' and try again."
      exit 1
    end

    self.puzzle_states = puzzle_states_from_file.each_with_object({}) do |(state, data), memo|
      memo[state] = data.map do |datum|
        {
          side1: datum['side1'].map(&:to_sym),
          side2: datum['side2'].map(&:to_sym),
          max_num_weighs_to_solve: datum['max_num_weighs_to_solve'],
        }
      end
    end
  end

  private

  def create_puzzle_states_for_low_coins
    Logger.log("-> Calculating all possible puzzle states when there are only coins we think might be light.")

    (2..NUM_INCORRECT_COINS_TO_CONSIDER).each do |num_coins|
      coin_states = [:LOW] * num_coins
      calculate_all_coin_perms_for_weighing_and_their_num_weighs_to_solution(coin_states)
    end
  end

  def create_puzzle_states_for_high_coins
    Logger.log("-> Calculating all possible puzzle states when there are only coins we think might be heavy.")

    (2..NUM_INCORRECT_COINS_TO_CONSIDER).each do |num_coins|
      coin_states = [:HIGH] * num_coins
      calculate_all_coin_perms_for_weighing_and_their_num_weighs_to_solution(coin_states)
    end
  end

  def create_puzzle_states_for_low_high_coin_combos
    Logger.log("-> Calculating all possible puzzle states when there are some coins we think might be light and some coins we think might be heavy.")

    (1..NUM_INCORRECT_COINS_TO_CONSIDER).each do |num_low|
      (1..NUM_INCORRECT_COINS_TO_CONSIDER).each do |num_high|
        calculate_all_coin_perms_for_weighing_and_their_num_weighs_to_solution([:LOW] * num_low + [:HIGH] * num_high)
      end
    end
  end

  def create_puzzle_state_for_unknown_coins
    Logger.log("-> Calculating all possible puzzle states when there are only coins we don't know anything about.")

    (1..13).map do |num_coins|
      states = [:UNKNOWN] * num_coins
      calculate_all_coin_perms_for_weighing_and_their_num_weighs_to_solution(states)
    end
  end

  def calculate_all_coin_perms_for_weighing_and_their_num_weighs_to_solution(bad_coin_states)
    scale_schemas = compute_scale_schemas(bad_coin_states)

    scale_schemas.each do |scale_schema|
      max_num_weighs_to_solve = calculate_max_num_weighs_to_solve(bad_coin_states, scale_schema)

      orig_bad_states = scale_schema.flatten.select { |state| Coin::BAD_COIN_STATES.values.include?(state) }
      puzzle_states[state_name(bad_coin_states)] ||= []

      puzzle_states[state_name(bad_coin_states)] << {
        side1: scale_schema[0],
        side2: scale_schema[1],
        max_num_weighs_to_solve: max_num_weighs_to_solve,
      }
    end
  end

  def calculate_max_num_weighs_to_solve(bad_coin_states, scale_schema)
    side1_schema, side2_schema = scale_schema

    uniq_side1_states = side1_schema.uniq
    uniq_side2_states = side2_schema.uniq

    max_num_weighs_to_solve = 0

    uniq_side1_states.each do |uniq_side1_state|
      coin_metadata = create_initial_coins(bad_coin_states, side1_schema, side2_schema)
      update_incorrect_coin_to_have_wrong_weight(coin_metadata[:side1_coins], uniq_side1_state)

      max_num_weighs_to_solve = [
        max_num_weighs_to_solve,
        weigh_and_compute_max_num_weighs_to_solve(
          bad_coin_states,
          coin_metadata[:all_coins],
          coin_metadata[:side1_coins],
          coin_metadata[:side2_coins],
        )
      ].max
    end

    uniq_side2_states.each do |uniq_side2_state|
      next if uniq_side2_state == :CORRECT

      coin_metadata = create_initial_coins(bad_coin_states, side1_schema, side2_schema)
      update_incorrect_coin_to_have_wrong_weight(coin_metadata[:side2_coins], uniq_side2_state)

      max_num_weighs_to_solve = [
        max_num_weighs_to_solve,
        weigh_and_compute_max_num_weighs_to_solve(
          bad_coin_states,
          coin_metadata[:all_coins],
          coin_metadata[:side1_coins],
          coin_metadata[:side2_coins],
        )
      ].max
    end

    coin_metadata = create_initial_coins(bad_coin_states, side1_schema, side2_schema)
    has_bad_coins_off_scale = !coin_metadata[:remaining_bad_coins][0].nil?

    if has_bad_coins_off_scale
      update_incorrect_coin_to_have_wrong_weight(coin_metadata[:remaining_bad_coins])

      max_num_weighs_to_solve = [
        max_num_weighs_to_solve,
        weigh_and_compute_max_num_weighs_to_solve(
          bad_coin_states,
          coin_metadata[:all_coins],
          coin_metadata[:side1_coins],
          coin_metadata[:side2_coins],
        )
      ].max
    end

    max_num_weighs_to_solve
  end

  def update_incorrect_coin_to_have_wrong_weight(coins, state = nil)
    coin_to_change = coins.find { |coin| state ? coin.state == state : coin.not_correct? }
    coin_to_change.weight = coin_to_change.low? ? Coin::COIN_WEIGHTS.fetch(:LIGHT) : Coin::COIN_WEIGHTS.fetch(:HEAVY)
  end


  def weigh_and_compute_max_num_weighs_to_solve(orig_bad_states, all_coins, side1_coins, side2_coins)
    Scale.weigh_and_update(all_coins, side1_coins, side2_coins)

    new_bad_states = all_coins.select(&:not_correct?).map(&:state)

    if orig_bad_states == new_bad_states
      return MAX_NUM_WEIGHS_TO_SOLVE
    end

    return 1 if all_coins.select(&:not_correct?).length == 1

    puzzle_states.fetch(state_name(new_bad_states)).map do |puzzle_state|
      puzzle_state.fetch(:max_num_weighs_to_solve)
    end.min + 1
  end

  def create_initial_coins(bad_coin_states, side1_schema, side2_schema)
    count_bad_coins_by_state = count_coins_by_state(bad_coin_states)
    side1_coins = side1_schema.map { |state| Coin.new(state) }
    side2_coins = side2_schema.map { |state| Coin.new(state) }
    coins_on_scale = side1_coins + side2_coins
    remaining_bad_coins = []

    count_bad_coins_by_state.each do |bad_coin_state, count_coins_with_bad_state|
      coins_on_scale_with_bad_state = coins_on_scale.select { |coin| coin.has_state(bad_coin_state) }

      (count_coins_with_bad_state - coins_on_scale_with_bad_state.length).times do
        remaining_bad_coins << Coin.new(bad_coin_state)
      end
    end

    all_coins = side1_coins + side2_coins + remaining_bad_coins

    remaining_good_coins = (13 - all_coins.length).times.map { Coin.new(:CORRECT) }
    all_coins += remaining_good_coins

    {
      side1_coins: side1_coins,
      side2_coins: side2_coins,
      remaining_bad_coins: remaining_bad_coins,
      all_coins: all_coins,
    }
  end

  def find_max_num_weighs_to_solve(orig_bad_states, new_bad_states)
  end

  def compute_scale_schemas(incorrect_coin_states_in_coin_list)
    max_num_coins_on_scale = [incorrect_coin_states_in_coin_list.length * 2, Constants::NUM_COINS].min
    num_coins_per_state = count_coins_by_state(incorrect_coin_states_in_coin_list)
    uniq_incorrect_states = incorrect_coin_states_in_coin_list.uniq
    uniq_all_states = uniq_incorrect_states + [:CORRECT]
    uniq_schemas_added = Set.new
    schemas = []


    (2..max_num_coins_on_scale).step(2).each do |num_coins_on_scale|
      uniq_all_states.cartesian_power(num_coins_on_scale).each do |coin_states_on_scale|
        side1_states, side2_states = coin_states_on_scale.split

        # We want to skip any schema that has a correct coin on both sides,
        # since they cancel each other out. Therefore, there must always be one
        # side that has zero correct coins. We choose side1 to always be that
        # side to simplify the weighing logic.
        next if side1_states.any? { |state| state == :CORRECT }

        num_coins_per_state_on_scale = count_coins_by_state(coin_states_on_scale)

        # If there are more states in this perm than expected, skip.
        has_more_coins_of_state_than_expected = num_coins_per_state.any? do |state, actual_count_coins_for_state|
          num_coins_per_state_on_scale[state] && num_coins_per_state_on_scale[state] > actual_count_coins_for_state
        end

        next if has_more_coins_of_state_than_expected

        max_num_correct_coins = Constants::NUM_COINS - incorrect_coin_states_in_coin_list.length

        next if num_coins_per_state_on_scale[:CORRECT] && num_coins_per_state_on_scale[:CORRECT] > max_num_correct_coins

        # Exclude a schema if it's the reverse of a schema we've already added
        # to our list. E.g weighing LOW vs HIGH is the same as weighing HIGH vs LOW.
        side1_string = side1_states.sort.join
        side2_string = side2_states.sort.join
        id1 = "#{side1_string}:#{side2_string}"
        id2 = "#{side2_string}:#{side1_string}"

        next if uniq_schemas_added.include?(id1) || uniq_schemas_added.include?(id2)

        uniq_schemas_added << id1
        uniq_schemas_added << id2

        schemas.push([side1_states, side2_states])
      end
    end

    schemas
  end

  def state_name(bad_states)
    count_bad_states_by_coin = count_coins_by_state(bad_states)

    count_bad_states_by_coin.keys.sort.map do |bad_coin_state|
      "#{bad_coin_state}-#{count_bad_states_by_coin[bad_coin_state]}"
    end.join(':')
  end

  def count_coins_by_state(states)
    states.each_with_object({}) do |state, memo|
      memo[state] ||= 0
      memo[state] += 1
    end
  end
end
