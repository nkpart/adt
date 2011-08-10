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
        ok(:value)
        missing
        invalid(:reason)
      end
    end

What you now have:

* Constructors for each of the cases: Type._case_(arg)
* A `fold` method, for matching on all the cases.
* A good #== and #inspect implementation
* #_case_? and #when__case_(handle_case_proc, default_proc) for dealing with a single case

Check the [documentation](http://rubydoc.info/gems/adt/0.0.1/ADT:cases) for more information.

Examples:

    # Create values
    mine = ValidatedValue.ok(5)
    missing = ValidatedValue.missing
    invalid = ValidatedValue.invalid("Wrong number!")
    
    # Define operations on a value, only the proc matching the value's case will be 
    # executed
    mine.fold(
        proc { |value| value },
        proc { "missing default" }
        proc { |reason| raise "gah. Invalid is terrible" }
    )

    mine.ok? # <= true
    mine.when_missing(proc { "I'm missing!" }, proc { "It's okay I'm around" })

    mine.fold(
        :ok => proc { |value| value },
        :missing => proc { "missing default " },
        :invalid => proc { |reason| raise "gah. Invalid is terrible!" }
    )

    # == does what you expect.
    mine == ValidatedValue.missing # <= false
    mine == ValidatedValue.ok(5) # <= true

    # Inspect looks good.
    mine.inspect # <= "#<ValidatedValue ok value:5>"

More Information on ADTs
------------------------

* http://blog.tmorris.net/algebraic-data-types-again/
* http://en.wikibooks.org/wiki/Haskell/Type_declarations#data_and_constructor_functions
* http://en.wikipedia.org/wiki/Algebraic_data_type 
