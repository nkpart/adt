
class Identity
  extend ADT
  
  cases do
    wrap(:value)
  end

  operation :get do
    wrap { |value| value }
  end
end

class Maybe # This is Option in scala.
  extend ADT

  cases do
    nothing
    just(:value)
  end

  operation :or_value do |default|
    nothing { default }
    just { |value| value }
  end
end

class Either # Disjunction
  extend ADT

  cases do
    left(:value)
    right(:value)
  end
end

