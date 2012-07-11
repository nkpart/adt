require 'adt'

class Validation
  extend ADT
  cases do
    failure(:errors)
    success(:value)
  end

  def self.fail_with(error)
    failure([error])
  end

  def map
    fold(proc { |_| self }, proc { |v| Validation.success(yield v) })
  end

  def bind(&b)
    fold(proc { |_| self }, b)
  end
end
