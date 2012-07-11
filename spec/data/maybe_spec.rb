require 'data/maybe'

describe Maybe do
  let(:one) { rand }
  let(:two) { rand }
  let(:only_pos) { proc { |v| v > 0 ? Maybe.just(v) : Maybe.nothing } }
  it("#map") { Maybe.just(5).map(&:succ).should == Maybe.just(6) }
  it("#bind") { Maybe.just(5).bind(&only_pos).should == Maybe.just(5) }
  it("#or_else") {
    Maybe.just(one).or_else(Maybe.just(two)).should == Maybe.just(one)
    Maybe.just(one).or_else{Maybe.just(two)}.should == Maybe.just(one)
    Maybe.nothing.or_else(Maybe.just(two)).should == Maybe.just(two)
  }

  it("#or_value") {
    Maybe.just(one).or_value(two).should == one
    Maybe.nothing.or_value(two).should == two
    Maybe.nothing.or_value { two }.should == two
  }

  it("#filter") {
    Maybe.nothing.filter { |x| true }.should == Maybe.nothing
    Maybe.just(one).filter { |x| x > one }.should == Maybe.nothing
    Maybe.just(one).filter { |x| x == one }.should == Maybe.just(one)
  }
  
  it("#to_a") {
    Maybe.just(one).to_a.should == [one]
    Maybe.nothing.to_a.should == []
  }

  it("::from_nil") {
    Maybe.from_nil(nil).should == Maybe.nothing
    Maybe.from_nil(one).should == Maybe.just(one)
  }

  # We get these for free from ADT
  let(:just_and_nothing) { [Maybe.just(one), Maybe.nothing] }
  it {
    just_and_nothing.map(&:just?).should == [true, false]
    just_and_nothing.map(&:nothing?).should == [false, true]
    just_and_nothing.map(&:to_a).should == [[one], []]
  }
end

