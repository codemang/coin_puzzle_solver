require 'byebug'
require 'combinatorics'
require 'json'

class PuzzleSolver
  attr_accessor :coins, :split_perms, :failed_steps, :coin_positions

  def initialize(coins)
    @coins = coins
    @failed_steps = Set.new
    @coin_positions = (0..12).to_a
  end

  def generate_split_perms
    split_perms = []
    fingerprint = {}

    [1,2,3,4,5].each do |num_coins_per_side|
      coin_positions.choose(num_coins_per_side).each do |side1|
        coin_positions.choose(num_coins_per_side).each do |side2|
          next if (side1 & side2).length > 0
          next if side1.length != side2.length

          id1 = side1.sort.join('-') + side2.sort.join('-')
          id2 = side2.sort.join('-') + side1.sort.join('-')

          next if fingerprint[id1] || fingerprint[id2]

          fingerprint[id1] = true
          fingerprint[id2] = true

          split_perms << {
            side1: side1,
            side2: side2,
          }
        end
      end
    end

    split_perms
  end

  def save_split_perms
    split_perms = generate_split_perms

    split_perms.each do |perm|
      perm[:side1] = perm[:side1].to_a
      perm[:side2] = perm[:side2].to_a
    end

    File.open('split_perms.json', 'w') { |f| f.puts(split_perms.to_json) }
  end

  def read_split_perms
    JSON.parse(File.read('split_perms.json'))
  end

  def solve
    @split_perms = read_split_perms
    recurse
  end

  def recurse(step = 3, solution = nil )
    solution ||= {
      good_indexes: Set.new,
    }

    if step == 0
      if solution[:good_indexes].length == 12
        byebug
      end
      return
    end

    split_perms.each do |split_perm|
      indexes_to_weigh = split_perm['side1'] + split_perm['side2']

      next if (indexes_to_weigh - solution[:good_indexes].to_a).length == 0

      weight = weigh(split_perm['side1'], split_perm['side2'])

      if weight == 0
        solution[:good_indexes].merge(split_perm['side1'])
        solution[:good_indexes].merge(split_perm['side2'])
      else
        missing_indexes = coin_positions - indexes_to_weigh
        solution[:good_indexes].merge(missing_indexes)
      end

      recurse(step - 1, solution)
    end
  end

  def weigh(side1, side2)
    side1_sum = side1.sum { |coin_index| coins[coin_index] }
    side2_sum = side2.sum { |coin_index| coins[coin_index] }
    side1_sum <=> side2_sum
  end
end
coins = 13.times.map { 1 }
coins[6] = 1.5

[
  {
    sides: 2012,
    step: 3,
    ifSame: {
      sides: 8,
      step: 4,
    }
  }
]

PuzzleSolver.new(coins).solve
