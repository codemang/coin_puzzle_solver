class Scale
  def self.weigh_and_update(all_coins, side1_coins, side2_coins)
    raise if side2_coins.length != side1_coins.length

    weight_delta = side1_coins.sum(&:weight) - side2_coins.sum(&:weight)

    if weight_delta == 0
      process_even_scale(all_coins, side1_coins, side2_coins)
    else
      process_uneven_scale(all_coins, side1_coins, side2_coins, weight_delta)
    end

    did_mark_incorrect_coin_as_correct = all_coins.select(&:not_normal_weight?).any?(&:correct?)

    raise if did_mark_incorrect_coin_as_correct
  end

  def self.process_even_scale(all_coins, side1_coins, side2_coins)
    side1_coins.each(&:mark_correct)
    side2_coins.each(&:mark_correct)
  end

  def self.process_uneven_scale(all_coins, side1_coins, side2_coins, weight_delta)
    is_first_weigh = all_coins.all?(&:unknown?)

    missing_coins = all_coins.select { |coin| !side1_coins.map(&:id).include?(coin.id) && !side2_coins.map(&:id).include?(coin.id) }
    missing_coins.each(&:mark_correct)

    if is_first_weigh
      if weight_delta > 0
        side2_coins.each(&:mark_low)
        side1_coins.each(&:mark_high)
      else
        side1_coins.each(&:mark_low)
        side2_coins.each(&:mark_high)
      end

      return
    end

    uniq_states = all_coins.select(&:not_correct?).map(&:state).uniq

    if uniq_states.length == 1 && Coin::BAD_COIN_STATES.values.include?(uniq_states[0])
      process_known_direction_bad_states(all_coins, side1_coins, side2_coins, weight_delta)
    else
      process_unknown_direction_bad_states(all_coins, side1_coins, side2_coins, weight_delta)
    end
  end

  def self.process_unknown_direction_bad_states(all_coins, side1_coins, side2_coins, weight_delta)
    if side2_coins.all?(&:correct?)
      if weight_delta > 0
        side1_coins.each do |coin|
          if coin.state == :LOW
            coin.state = :CORRECT
          end
        end
      else
        side1_coins.each do |coin|
          if coin.state == :HIGH
            coin.state = :CORRECT
          end
        end
      end
    end

    if side1_coins.any?(&:unknown?) || side2_coins.any?(&:unknown?)
      if weight_delta > 0
        side2_coins.each { |coin| coin.mark_low if coin.unknown? }
        side1_coins.each { |coin| coin.mark_high if coin.unknown? }
      else
        side1_coins.each { |coin| coin.mark_low if coin.unknown? }
        side2_coins.each { |coin| coin.mark_high if coin.unknown? }
      end
    end
  end

  def self.process_known_direction_bad_states(all_coins, side1_coins, side2_coins, weight_delta)
    uniq_states = all_coins.select(&:not_correct?).map(&:state).uniq

    if uniq_states[0] ==:LOW
      if weight_delta > 0
        side1_coins.each(&:mark_correct)
      else
        side2_coins.each(&:mark_correct)
      end
    else
      if weight_delta > 0
        side2_coins.each(&:mark_correct)
      else
        side1_coins.each(&:mark_correct)
      end
    end
  end
end
