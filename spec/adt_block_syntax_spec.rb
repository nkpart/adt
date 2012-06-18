require 'adt'

module Syntax
  # New hotness
  class Maybe
    extend ADT { nothing; just(:v) }
  end

  # Make sure old n busted is still okay
  class Count
    extend ADT
    cases do
      one
      two
    end
  end
end

describe Syntax::Maybe do
  it { Syntax::Maybe.just(3).should == Syntax::Maybe.just(3) }
  it { Syntax::Count.one.should == Syntax::Count.one }
end
