require 'adt'

class Maybe
  extend ADT
  cases do
    nothing
    just(:value)
  end

  def map
    fold(proc { self }, proc { |v| self.class.just(yield v) })
  end

  def bind
    fold(proc { self }, proc { |v| yield v })
  end

  def filter
    fold(proc { self }, proc { |v| yield(v) ? self : Maybe.nothing })
  end

  def or_else(other = nil)
    fold(proc { other || yield }, proc { |v| self }) 
  end

  def or_value(v = nil)
    fold(proc { v || yield }, proc { |v| v })
  end

  def or_nil
    fold(proc { nil }, proc { |v| v })
  end

  def self.from_nil(v)
    v.nil? ? nothing : just(v)
  end
end
