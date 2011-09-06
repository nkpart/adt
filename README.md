ADT
===

A library for declaring algebraic data types in Ruby.

Usage
-----

    gem install adt

ADT provides a DSL for specifying the cases in an algebraic data type.

    require 'adt'
    class ValidatedValue
      extend ADT
      cases do
        missing
        invalid(:reason)
        ok(:value)
      end
    end

    # An Enumeration (nullary constructors only)
    class State
      extend ADT
      cases do
        snafu
        smoking # 'Nullary contructor' means it takes no arguments
      end
    end

What you now have:

* Constructors for each of the cases: Type._case_(arg)
* A `fold` method, for matching on all the cases.
* A good #== and #inspect implementation
* \#_case_? and #when__case_(handle_case_proc, default_proc) for dealing with a single case

Check the [documentation](http://rubydoc.info/gems/adt/0.0.3/ADT:cases) for more information.

Usage examples
--------------

Construction:

    # Create values
    mine = ValidatedValue.ok(5)
    missing = ValidatedValue.missing
    invalid = ValidatedValue.invalid("Wrong number!")

Folding:

    # Define operations on a value, only the proc matching the value's case will be 
    # executed
    mine.fold(
        proc { |value| value },
        proc { "missing default" }
        proc { |reason| raise "gah. Invalid is terrible" }
    )

    # Use an alias to #fold, named after the type:
    mine.validated_value(
        :ok => proc { |value| value },
        :missing => proc { "missing default " },
        :invalid => proc { |reason| raise "gah. Invalid is terrible!" }
    )

Support methods:

    mine.ok? # <= true
    mine.when_missing(proc { "I'm missing!" }, proc { "It's okay I'm around" })

    # == does what you expect.
    mine == ValidatedValue.missing # <= false
    mine == ValidatedValue.ok(5) # <= true

    # <=> 
    ValidatedValue.ok(5) <=> ValidatedValue.ok(3) # <= 1 # Ordering is by the inner value(s), if the cases match
    ValidatedValue.ok(5) <=> ValidatedValue.missing # <= 1 # Otherwise it is by increasing order in which the cases are defined

    # to_a
    ValidatedValue.ok(5).to_a == [5]
    ValidatedValue.missing.to_a = []

    # Inspect looks good.
    mine.inspect # <= "#<ValidatedValue ok value:5>"

For the enumeration only:

    State.all_values # <= [State.snafu, State.smoking]
    State.snafu.to_i # <= 1
    State.from_i(2) # <= State.smoking

Case info:

    State.snafu.case_name == "snafu"
    ValidatedValue.ok(3).case_arity == 1
    State.snafu.case_index = 2

More Information on ADTs
------------------------

* http://blog.tmorris.net/algebraic-data-types-again/
* http://en.wikibooks.org/wiki/Haskell/Type_declarations#data_and_constructor_functions
* http://en.wikipedia.org/wiki/Algebraic_data_type 
