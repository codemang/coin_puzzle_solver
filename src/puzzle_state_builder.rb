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
  NUM_COINS = 13
  MAX_NUM_STEPS = 999

  attr_accessor :global_state

  def initialize
    @global_state = {}
  end

  def build
    Logger.log("Starting process to calculate all possible puzzle states and their distance from the final solution.")
    create_puzzle_states_for_low_coins
    clone_low_puzzle_states_to_high
    create_puzzle_states_for_low_high_coin_combos
    create_puzzle_state_for_unknown_coins
  end

  def save_to_file(filename = 'tmp/puzzle_states.json')
    File.open(filename, 'w') { |f| f.puts global_state.to_json }
  end

  def read_from_file(filename = 'tmp/puzzle_states.json')
    self.global_state = JSON.parse(File.read(filename))

    global_state.each do |state, data|
      data.each do |datum|
        datum.merge!(datum.transform_keys(&:to_sym))
      end
    end
  end

  private

  def create_puzzle_states_for_low_coins
    Logger.log("-> Calculating all possible puzzle states when there are only coins we think might be light.")

    5.times.map do |index|
      states = [:LOW] * (index + 2)
      calculate_ideal_step(states)
    end
  end

  def clone_low_puzzle_states_to_high
    Logger.log("-> Calculating all possible puzzle states when there are only coins we think might be heavy.")

    5.times.map do |index|
      states = [:HIGH] * (index + 2)
      calculate_ideal_step(states)
    end
  end

  def create_puzzle_states_for_low_high_coin_combos
    Logger.log("-> Calculating all possible puzzle states when there are some coins we think might be light and some coins we think might be heavy.")

    num_coins = 6
    num_lows_and_highs = []

    (1..num_coins).each do |num_low|
      (1..num_coins).each do |num_high|
        next if num_low + num_high > Constants::NUM_COINS

        num_lows_and_highs << [num_low, num_high]
      end
    end

    num_lows_and_highs.each do |num_low_and_high|
      low, high = num_low_and_high
      calculate_ideal_step([:LOW] * low + [:HIGH] * high)
    end
  end

  def create_puzzle_state_for_unknown_coins
    Logger.log("-> Calculating all possible puzzle states when there are only coins we don't know anything about.")

    (1..13).map do |num_coins|
      states = [:UNKNOWN] * num_coins
      calculate_ideal_step(states)
    end
  end

  def calculate_ideal_step(bad_coin_states)
    # e.g [['LOW', 'HIGH'], ['LOW', 'CORRECT']]
    scale_schemas = compute_scale_schemas(bad_coin_states)

    fingerprint = {}
    final_scale_schemas = []

    scale_schemas.each do |scale_schema|
      side1 = scale_schema[0].sort.join
      side2 = scale_schema[1].sort.join

      id1 = "#{side1}:#{side2}"
      id2 = "#{side2}:#{side1}"

      next if fingerprint[id1] || fingerprint[id2]

      fingerprint[id1] = true
      fingerprint[id2] = true

      final_scale_schemas << scale_schema
    end

    final_scale_schemas.each do |scale_schema|
      max_step = new(bad_coin_states, scale_schema)

      orig_bad_states = scale_schema.flatten.select { |state| Coin::BAD_COIN_STATES.values.include?(state) }
      global_state[state_name(bad_coin_states)] ||= []

      global_state[state_name(bad_coin_states)] << {
        side1: scale_schema[0],
        side2: scale_schema[1],
        max_step: max_step,
      }
    end
  end

  def new(bad_coin_states, scale_schema)
    side1_schema, side2_schema = scale_schema

    uniq_side1_states = side1_schema.uniq
    uniq_side2_states = side2_schema.uniq

    max_step = 0

    uniq_side1_states.each do |uniq_side1_state|
      coin_metadata = create_initial_coins(bad_coin_states, side1_schema, side2_schema)

      coin_to_change = coin_metadata[:side1_coins].find { |coin| coin.state == uniq_side1_state }
      coin_to_change.weight = coin_to_change.low? ? Coin::COIN_WEIGHTS.fetch(:LIGHT) : Coin::COIN_WEIGHTS.fetch(:HEAVY)

      max_step = [max_step, weigh_and_compute_max_step(bad_coin_states, scale_schema, coin_metadata)].max
    end

    uniq_side2_states.each do |uniq_side2_state|
      next if uniq_side2_state == 'CORRECT'

      coin_metadata = create_initial_coins(bad_coin_states, side1_schema, side2_schema)

      coin_to_change = coin_metadata[:side2_coins].find { |coin| coin.state == uniq_side2_state }
      coin_to_change.weight = coin_to_change.low? ? Coin::COIN_WEIGHTS.fetch(:LIGHT) : Coin::COIN_WEIGHTS.fetch(:HEAVY)
      max_step = [max_step, weigh_and_compute_max_step(bad_coin_states, scale_schema, coin_metadata)].max
    end

    coin_metadata = create_initial_coins(bad_coin_states, side1_schema, side2_schema)
    coin_to_change = coin_metadata[:remaining_bad_coins][0]

    if coin_to_change
      coin_to_change.weight = coin_to_change.low? ? Coin::COIN_WEIGHTS.fetch(:LIGHT) : Coin::COIN_WEIGHTS.fetch(:HEAVY)
      max_step = [max_step, weigh_and_compute_max_step(bad_coin_states, scale_schema, coin_metadata)].max
    end

    max_step
  end

  def weigh_and_compute_max_step(orig_bad_states, scale_schema, coin_metadata)
    Scale.weigh_and_update(coin_metadata[:all_coins], coin_metadata[:side1_coins], coin_metadata[:side2_coins])

    return 1 if coin_metadata[:all_coins].select(&:not_correct?).length == 1

    find_max_step(orig_bad_states.map(&:to_s), coin_metadata[:all_coins].select(&:not_correct?).map(&:state)) + 1
  end

  def create_initial_coins(bad_coin_states, side1_schema, side2_schema)
    count_coins_by_state = bad_coin_states.each_with_object({}) do |state, memo|
      memo[state] ||= 0
      memo[state] += 1
    end

      side1_coins = side1_schema.map { |state| Coin.new(state) }
      side2_coins = side2_schema.map { |state| Coin.new(state) }
      coins_on_scale = side1_coins + side2_coins

      remaining_bad_coins = []

      bad_coin_states.uniq.each do |bad_coin_state|
        matching_bad_coins = coins_on_scale.select { |coin| coin.has_state(bad_coin_state) }

        (count_coins_by_state[bad_coin_state] - matching_bad_coins.length).times do
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

  def find_max_step(orig_bad_states, new_bad_states)
    if orig_bad_states == new_bad_states
      return MAX_NUM_STEPS
    end

    global_state.fetch(state_name(new_bad_states)).map{|x| x.fetch(:max_step) }.min
  end

  def state_name(bad_states)
    state_count = bad_states.each_with_object({}) do |bad_state, memo|
      memo[bad_state] ||= 0
      memo[bad_state] += 1
    end

    state_count.keys.sort.map do |bad_coin_state|
      "#{bad_coin_state}-#{state_count[bad_coin_state]}"
    end.join(':')
  end

  def compute_scale_schemas(bad_coin_states)
    max_num_coins = [bad_coin_states.length * 2, NUM_COINS].min

    expected_count_states = bad_coin_states.each_with_object({}) do |state, memo|
      memo[state] ||= 0
      memo[state] += 1
    end

    schemas = []

    (2..max_num_coins).step(2).each do |num_coins|
      uniq_bad_states = bad_coin_states.uniq
      uniq_states = uniq_bad_states + [:CORRECT]

      states_to_scale_schemas = uniq_states.cartesian_power(num_coins).each do |coin_states|
        side1, side2 = coin_states.map { |state| Coin.new(state) }.split

        # Skip if any of side1 are correct
        next if side1.any?(&:correct?)

        current_count_states = coin_states.map(&:to_sym).each_with_object({}) do |state, memo|
          memo[state] ||= 0
          memo[state] += 1
        end

        # Skip if there are only correct coins
        next if current_count_states.keys.length == 1 && !current_count_states[:CORRECT].nil?

        # If there are more states in this perm than expected, skip.
        should_skip = expected_count_states.any? do |state, expected_count_for_state|
          current_count_states[state] && current_count_states[state] > expected_count_for_state
        end

        next if should_skip

        next if current_count_states[:CORRECT] && current_count_states[:CORRECT] > NUM_COINS - bad_coin_states.length

        schemas.push([side1.map(&:state), side2.map(&:state)])
      end.compact
    end

    schemas
  end
end
