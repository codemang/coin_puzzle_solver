class Coin
  attr_accessor :state, :weight, :id

  @@id = 1

  BAD_COIN_STATES = {
    FINAL_LOW: 'FINAL_LOW',
    FINAL_HEAVY: 'FINAL_HEAVY',
    LOW1: 'LOW1',
    LOW2: 'LOW2',
    HIGH1: 'HIGH1',
    HIGH2: 'HIGH2',
  }

  COIN_STATES = {
    UNKNOWN: 'UNKNOWN',
    CORRECT: 'CORRECT',
  }.merge(BAD_COIN_STATES)

  COIN_WEIGHTS = {
    NORMAL: 1,
    HEAVY: 1.5,
    LIGHT: 0.5,
  }

  def initialize(state = :UNKNOWN)
    @state = COIN_STATES.fetch(state.to_sym)
    @id = @@id
    @weight = COIN_WEIGHTS.fetch(:NORMAL)
    @@id += 1
  end

  def unknown?
    state == COIN_STATES.fetch(:UNKNOWN)
  end

  def correct?
    state == COIN_STATES.fetch(:CORRECT)
  end

  def not_correct?
    state != COIN_STATES.fetch(:CORRECT)
  end

  def upgrade
    if state == BAD_COIN_STATES.fetch(:LOW1)
      state = BAD_COIN_STATES.fetch(:LOW2)
    elsif state == BAD_COIN_STATES.fetch(:HIGH1)
      state = BAD_COIN_STATES.fetch(:HIGH2)
    else
      raise RuntimeError
    end
  end

  def mark_correct
    self.state = COIN_STATES.fetch(:CORRECT)
  end
end
