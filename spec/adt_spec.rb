require 'adt'

module Samples

  class Maybe
    extend ADT

    cases do
      just(:value)
      nothing
    end
  end

  class Either
    extend ADT

    cases do
      left(:value)
      right(:value)
    end
  end

  Meal = ADT do
    main
    snack(:size)
  end
end

describe ADT do
  include Samples
  it "#fold" do
    Maybe.just(5).fold(proc { |x| x + 1 }, proc { 3 }).should == 6
    Maybe.nothing.fold(proc { |x| x + 1 }, proc { 3 }).should == 3
  end

  it "#==" do
    Maybe.just(5).should == Maybe.just(5)
    Maybe.nothing.should == Maybe.nothing
    Maybe.just(5).should_not == Maybe.just(3)
    Maybe.just(5).should_not == Maybe.nothing
    Maybe.nothing.should_not == Maybe.just(2)
  end

  it "#case?" do
    Maybe.just(5).just?.should == true
    Maybe.just(5).nothing?.should == false

    Maybe.nothing.just?.should == false
    Maybe.nothing.nothing?.should == true
  end

  it "#when_case" do
    Maybe.just(5).when_just(proc { true }, proc { false }).should be_true
    Maybe.just(5).when_nothing(proc { true }, proc { false }).should be_false
  end

  it "#inspect" do
    Maybe.just(5).inspect.should == "#<Samples::Maybe just value:5>"
    Maybe.nothing.inspect.should == "#<Samples::Maybe nothing>"
  end

  it "alternative decl" do
    Meal.snack(5).snack?.should == true
  end
end
