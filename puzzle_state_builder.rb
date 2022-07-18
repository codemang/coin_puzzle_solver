require 'byebug'
require 'combinatorics'
require 'json'
require 'ostruct'
require_relative './coin'
require_relative './scale'
require_relative './constants'

# https://stackoverflow.com/a/15737305
class Array
  def cartesian_power(n)
    res = []
    current = [0] * n
    last = [size - 1] * n

    loop do
      res << current.reverse.collect { |i| self[i] }
      break if current == last

      (0...n).each do |index|
        current[index] += 1
        current[index] %= size

        break if current[index] > 0
      end
    end
    res
  end


  def split
    self.each_slice( (self.size/2.0).round ).to_a
  end
end

class PuzzleStateBuilder
  NUM_COINS = 13

  attr_accessor :global_state

  def initialize
    @global_state = {}
  end

  def solve
    build_state_for_just_low(4)
    clone_low_state
    build_state_for_low_high_combo
  end

  def clone_low_state
    high_state = {}

    global_state.each do |state, perms|
      new_state = state.gsub('LOW', 'HIGH')

      high_state[new_state] = perms.map do |perm|
        {
          side1: perm[:side1].map do |state|
            state == 'LOW' ? 'HIGH' : state
          end,
          side2: perm[:side2].map do |state|
            state == 'LOW' ? 'HIGH' : state
          end,
          max_step: perm[:max_step]
        }
      end
    end

    global_state.merge!(high_state)
  end

  def build_state_for_low_high_combo
    num_coins = 4
    num_lows_and_highs = []

    (1..num_coins).each do |num_low|
      (1..num_coins).each do |num_high|
        next if num_low + num_high > Constants::NUM_COINS

        num_lows_and_highs << [num_low, num_high]
      end
    end

    num_lows_and_highs.each do |num_low_and_high|
      low, high = num_low_and_high
      ENV['BYEBUG'] = 'true' if low == 4 && high == 4
      calculate_ideal_step([:LOW] * low + [:HIGH] * high)
    end
  end

  def build_state_for_just_low(num_coins)
    num_coins.times.map do |index|
      states = [:LOW] * (index + 2)
      calculate_ideal_step(states)
    end
  end


  def calculate_ideal_step(bad_coin_states)
    bad_coins = bad_coin_states.map { |state| Coin.new(state) }

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

      perms = compute_perms(bad_coins, scale_schema)
      max_step = test_perm(bad_coins, perms)
      # byebug if ENV['BYEBUG'] == 'true' && scale_schema[0].sort == ['HIGH', 'HIGH', 'HIGH', 'LOW', 'LOW'] && scale_schema[1] == ['CORRECT','CORRECT','CORRECT','CORRECT','CORRECT']

      global_state[state_name(bad_coins)] ||= []

      global_state[state_name(bad_coins)] << {
        side1: scale_schema[0],
        side2: scale_schema[1],
        max_step: max_step,
      }
    end
  end

  def test_perm(bad_coins, perms)
    max_step = 0
    good_coins = (NUM_COINS - bad_coins.length).times.map { Coin.new(:CORRECT) }

    bad_coins.each do |bad_coin|
      if bad_coin.state.to_s =~ /HIGH/
        bad_coin.weight = Coin::COIN_WEIGHTS.fetch(:HEAVY)
      else
        bad_coin.weight = Coin::COIN_WEIGHTS.fetch(:LIGHT)
      end

      perms.values.comprehension.to_a.each do |schemas|
        side1_coins = []
        side2_coins = []

        dup_bad_coins = bad_coins.map(&:dup)
        all_coins = dup_bad_coins + good_coins

        schemas.each do |schema|
          side1_coins += dup_bad_coins.select { |x| schema[:side1].include?(x.id) }
          side2_coins += dup_bad_coins.select { |x| schema[:side2].include?(x.id) }
        end

        coin_delta = side1_coins.length - side2_coins.length
        side2_coins += good_coins.slice(0, coin_delta)

        raise if side2_coins.length != side1_coins.length

        Scale.weigh_and_update(all_coins, side1_coins, side2_coins)

        if dup_bad_coins.select(&:not_correct?).length == 1
          max_step = [max_step, 1].max
        else
          begin
          max_step = [max_step, find_max_step(bad_coins, dup_bad_coins, all_coins) + 1].max
          rescue
            raise
            byebug
          end
        end
      end

      bad_coin.weight = Coin::COIN_WEIGHTS.fetch(:NORMAL)
    end

    # global_state[state_name(bad_coins)] = { step: max_step }
    max_step
  end

  def find_max_step(orig_bad_coins, dup_bad_coins, all_coins)
    if orig_bad_coins.select(&:not_correct?).map(&:state).sort == all_coins.select(&:not_correct?).map(&:state).sort
      return Float::INFINITY
    end

    global_state.fetch(state_name(dup_bad_coins.select(&:not_correct?))).map{|x| x.fetch(:max_step) }.min
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

  def compute_perms(bad_coins, scale_schema)
    side1_state_counts = scale_schema[0].each_with_object({}) do |state, memo|
      memo[state] ||= 0
      memo[state] += 1
    end

    side2_state_counts = scale_schema[1].each_with_object({}) do |state, memo|
      memo[state] ||= 0
      memo[state] += 1
    end

    all_state_perms = {}

    states = scale_schema.flatten.uniq

    states.each do |state|
      next if state == 'CORRECT'

      state_perms = []

      matching_bad_coins = bad_coins.select do |bad_coin|
        bad_coin.state == state
      end

      side1_count = side1_state_counts[state]
      side2_count = side2_state_counts[state]

      if side1_count && side2_count
        matching_bad_coins.map(&:id).choose(side1_count).each do |side1_coin_perms|
          other_ids = matching_bad_coins.map(&:id) - side1_coin_perms.to_a

          other_ids.choose(side2_count).each do |side2_coin_perms|
            state_perms.push(side1: side1_coin_perms.to_a, side2: side2_coin_perms.to_a)
          end
        end
      elsif side1_count
        matching_bad_coins.map(&:id).choose(side1_count).each do |side1_coin_perms|
          state_perms.push(side1: side1_coin_perms.to_a, side2: [])
        end
      elsif side2_count
        matching_bad_coins.map(&:id).choose(side2_count).each do |side2_coin_perms|
          state_perms.push(side1: [], side2: side2_coin_perms.to_a)
        end
      else
        byebug
        raise
        #
      end

      all_state_perms[state] = state_perms
    end

    all_state_perms
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

        # Skip ifi any of side1 are correct
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
