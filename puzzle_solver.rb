require 'byebug'
require 'combinatorics'
require 'json'
require 'ostruct'
require_relative './constants'
require_relative './coin'
require_relative './scale'

class PuzzleSolver
  def self.solve
    starting_coins = Constants::NUM_COINS.times.map { Coin.new(:UNKNOWN) }

    global_state = JSON.parse(File.read('global_state.json'))
    steps = {}

    # TODO: Use 12
    (2..8).step(2).each do |num_coins_on_scale|
      max_step = 0

      dup_starting_coins = starting_coins.map(&:dup)
      side1_coins = dup_starting_coins.slice(0, num_coins_on_scale / 2)
      side2_coins = dup_starting_coins.slice(side1_coins.length, num_coins_on_scale / 2)
      side1_coins[0].make_light
      Scale.weigh_and_update(dup_starting_coins, side1_coins, side2_coins)

      new_step = global_state[state_name(dup_starting_coins.select(&:not_correct?))].map{|x| x['max_step'] == -1 ? Float::INFINITY : x['max_step']}.min
      max_step = [max_step, new_step].max

      dup_starting_coins = starting_coins.map(&:dup)
      side1_coins = dup_starting_coins.slice(0, num_coins_on_scale / 2)
      side2_coins = dup_starting_coins.slice(side1_coins.length, num_coins_on_scale / 2)
      side2_coins[0].make_light
      Scale.weigh_and_update(dup_starting_coins, side1_coins, side2_coins)

      new_step = global_state[state_name(dup_starting_coins.select(&:not_correct?))].map{|x| x['max_step'] == -1 ? Float::INFINITY : x['max_step']}.min
      max_step = [max_step, new_step].max

      dup_starting_coins = starting_coins.map(&:dup)
      side1_coins = dup_starting_coins.slice(0, num_coins_on_scale / 2)
      side2_coins = dup_starting_coins.slice(side1_coins.length, num_coins_on_scale / 2)
      dup_starting_coins.last.make_light
      Scale.weigh_and_update(dup_starting_coins, side1_coins, side2_coins)

      byebug
      new_step = global_state[state_name(dup_starting_coins.select(&:not_correct?))].map{|x| x['max_step'] == -1 ? Float::INFINITY : x['max_step']}.min
      max_step = [max_step, new_step].max

      steps[num_coins_on_scale] = max_step
    end
    byebug
  end

  def self.state_name(bad_coins)
    state_count = bad_coins.each_with_object({}) do |bad_coin, memo|
      memo[bad_coin.state] ||= 0
      memo[bad_coin.state] += 1
    end

    bad_coins.map(&:state).uniq.sort.map do |bad_coin_state|
      "#{bad_coin_state}-#{state_count[bad_coin_state]}"
    end.join(':')
  end
end
