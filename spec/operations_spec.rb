require 'adt'
require 'rspec'

class Identity
  extend ADT
  cases do
    value(:value)
  end
end

describe "Defining operations on a class" do
  it "allows defining of operations!" do
    baz = Identity.dup
    baz.class_eval do
      operation :get do
        value { |value| value } 
      end
    end
    baz.value(5).get.should == 5
  end

  it "allows operations that take arguments" do
    baz = Identity.dup
    baz.class_eval do
      operation :incr do |amount|
        value { |value| value + amount }
      end
    end
    baz.value(5).incr(1).should == 6
  end

  it "fails for operations that don't define all the cases" do
    baz = Identity.dup
    baz.class_eval do operation(:nothing) {} end
    proc { baz.value(5).nothing }.should raise_error
  end

  it "works if you use a helper method" do
    baz = Identity.dup
    baz.class_eval do
      def help; 5; end
      operation :incr do
        value { |v| v + help }
      end
    end
    baz.value(5).incr.should == 10
  end
end

