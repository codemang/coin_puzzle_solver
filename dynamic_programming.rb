require 'byebug'
require 'combinatorics'
require 'json'
require 'ostruct'
require_relative './coin'

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

class PuzzleSolver
  NUM_COINS = 13

  attr_accessor :global_state

  def initialize
    @global_state = {}
  end

  def solve
    13.times.map do |index|
      states = [:LOW1] * (index + 2)
      calculate_ideal_step(states)
    end
    byebug
  end


  def calculate_ideal_step(bad_coin_states)
    bad_coins = bad_coin_states.map { |state| Coin.new(state) }

    # if bad_coin_states.length == 1
    #   global_state[state_name(bad_coins)] = { step: 0 }
    #   return
    # end

    scale_schemas = compute_scale_schemas(bad_coin_states)

    # byebug if bad_coin_states.length == 8

    scale_schemas.each do |scale_schema|
      perms = compute_perms(bad_coins, scale_schema)
      max_step = test_perm(bad_coins, perms)

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

        # raise if side2_coins.length != side1_coins.length
        byebug if side2_coins.length != side1_coins.length

        weigh(all_coins, side1_coins, side2_coins)

        if dup_bad_coins.select(&:correct?).length == dup_bad_coins.length - 1
          max_step = [max_step, 1].max
        else
          max_step = [max_step, find_max_step(bad_coins, dup_bad_coins, all_coins) + 1].max
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

  def weigh(all_coins, side1_coins, side2_coins)
    weight_delta = side1_coins.sum(&:weight) - side2_coins.sum(&:weight)
    missing_coins = all_coins.select { |coin| !side1_coins.map(&:id).include?(coin.id) && !side2_coins.map(&:id).include?(coin.id) }

    if weight_delta == 0
      side1_coins.each(&:mark_correct)
      side2_coins.each(&:mark_correct)
      return
    end

    # if side2_coins.all?(&:correct?)
    #   side1_coins.each(&:upgrade)
    # end

    uniq_states = all_coins.select(&:not_correct?).map(&:state).uniq

    if uniq_states.count == 1 && uniq_states[0] =~ /1/
      if uniq_states[0] =~ /LOW/
        missing_coins.each(&:mark_correct)

        if weight_delta > 0
          side1_coins.each(&:mark_correct)
        else
          side2_coins.each(&:mark_correct)
        end
      else
      end
    end

    # If the scale was incorrect, and there is only one possible coin on the scale, mark it as final.
    if side1_coins.all?(&:correct?) && side2_coins.select(&:not_correct?).length == 1
      side2_coins.find(&:not_correct?).state = Coin::COIN_STATES.fetch(:FINAL_LOW)
    end

    # If the scale was incorrect, and there is only one possible coin on the scale, mark it as final.
    if side2_coins.all?(&:correct?) && side1_coins.select(&:not_correct?).length == 1
      side1_coins.find(&:not_correct?).state = Coin::COIN_STATES.fetch(:FINAL_LOW)
    end

    if all_coins.select(&:correct?).length == all_coins.length - 1
      all_coins.find(&:not_correct?).state = Coin::COIN_STATES.fetch(:FINAL_LOW)
    end

    raise if all_coins.find { |x| x.weight != 1 }.correct?
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

    side1_state_counts.each do |side1_state, side1_count|
      state_perms = []

      matching_bad_coins = bad_coins.select do |bad_coin|
        bad_coin.state == side1_state
      end

      matching_bad_coins.map(&:id).choose(side1_count).each do |side1_coin_perms|
        side2_state_count = side2_state_counts[side1_state]
        other_ids = matching_bad_coins.map(&:id) - side1_coin_perms.to_a

        if side2_state_count.nil?
          state_perms.push(side1: side1_coin_perms.to_a, side2: [], state: side1_state)
        else
          other_ids.choose(side2_state_count).each do |side2_coin_perms|
            state_perms.push(side1: side1_coin_perms.to_a, side2: side2_coin_perms.to_a, state: side1_state)
          end
        end
      end

      all_state_perms[side1_state] = state_perms
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
          current_count_states[state] > expected_count_for_state
        end

        next if should_skip

        next if current_count_states[:CORRECT] && current_count_states[:CORRECT] > NUM_COINS - bad_coin_states.length


        schemas.push([side1.map(&:state), side2.map(&:state)])
      end.compact
    end

    schemas
  end
end

puts PuzzleSolver.new.solve
# PuzzleSolver.new.test2
