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
