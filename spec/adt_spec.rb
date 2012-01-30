require 'adt'

class Maybe
  extend ADT

  cases do
    nothing
    just(:value)
  end
end

class Meal
  extend ADT
  cases do
    snack(:size)
    main
  end
end

class LolStatus 
  extend ADT
  cases do srs; active; end
end

describe ADT do
  context "instance methods" do
    it "#fold" do
      Maybe.just(5).fold(proc { 3 }, proc { |x| x + 1 }).should == 6
      Maybe.nothing.fold(proc { 3 }, proc { |x| x + 1 }).should == 3
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
      Maybe.just(5).inspect.should == "#<Maybe just value:5>"
      Maybe.just([5]).inspect.should == "#<Maybe just value:[5]>"
      Maybe.nothing.inspect.should == "#<Maybe nothing>"
    end

    it "aliases fold to type" do
      LolStatus.srs.lol_status(proc { true }, proc { false }).should == true
    end

    it "to_a" do
      Maybe.just(5).to_a.should == [5]
      Maybe.nothing.to_a.should == []
    end

    # Tests a bug that surfaced, where constructors were being generated in the wrong scope
    it "alternative decl" do
      Meal.snack(5).snack?.should == true
    end
  end

  context "constructors" do
    it "uses constant values for unary constructors" do
      Maybe.nothing.object_id.should == Maybe.nothing.object_id
    end

    it "does not overlap constructors" do
      Maybe.respond_to?(:srs).should be_false
    end
  end

  describe "enumerations" do
    it "creates an all cases accessor if the type is an enumeration" do
      LolStatus.all_values.should == [LolStatus.srs, LolStatus.active]
    end

    it "no all cases if not an enumeration" do
      Maybe.respond_to?(:all_values).should be_false
    end

    it "has to_i/from_i, which are 1-based" do
      LolStatus.all_values.each_with_index { |cse, idx|
        cse.to_i.should == (idx + 1)
        LolStatus.from_i(idx + 1).should == cse
      }
    end
  end

  context "comparable" do
    it "<=>" do
      (Maybe.just(5) <=> Maybe.just(10)).should == -1
      (Maybe.just(5) <=> Maybe.just(2)).should == 1
      (Maybe.just(5) <=> Maybe.nothing).should == 1
      (Maybe.nothing <=> Maybe.just(1)).should == -1
    end

    it "Comparable" do
      (Maybe.just(5) > Maybe.just(3)).should be_true
      (Maybe.nothing < Maybe.just(3)).should be_true
    end
  end

  context "constructor metadata" do
    it "#case_name" do
      Maybe.just(5).case_name.should == "just"
    end
    it "#case_index" do
      Maybe.just(5).case_index.should == 2
    end
    it "#case_arity" do
      Maybe.just(5).case_arity.should == 1
      Maybe.nothing.case_arity.should == 0
    end
  end

  context "declaration" do
    it "can be used in a name-less class" do
      cls = Class.new do
        extend ADT
        cases do one(:v) end
      end
      cls.one(5).to_a.should == [5]
    end
  end
end
