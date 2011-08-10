require 'adt/case_recorder'

module ADT
  module_function

  # Configures the class to be an ADT. Cases are defined by calling 
  # methods named for the case, and providing symbol arguments for 
  # the parameters to the case.
  #
  # eg.
  #
  #     class Validation
  #       extend ADT
  #       cases do
  #         success(:values)
  #         failure(:errors, :position)
  #       end
  #     end
  # 
  # This will provde 2 core pieces of functionality.
  # 
  # 1. Constructors, as class methods, named the same as the case, and expecting
  #    parameters as per the symbol arguments provided in the `cases` block.
  #      @failure = Validation.failure(["error1"], 5)
  #      @success = Validation.success([1,2])
  # 2. #fold. This method takes a proc for every case. If the case has parameters, those
  #    will be passed to the proc. The proc matching the particular value of the case will
  #    be called. Using this method, every instance method for the ADT can be defined.
  #      @failure.fold(
  #        proc { |values| "We are a success! #{values} "},
  #        proc { |errors, position| "Failed :(, at position #{position}" }
  #      )
  #    It can also be passed a hash of procs, keyed by case name:
  #      @failure.fold(
  #        :success => proc { |values| values },
  #        :failures => proc { |errors, position| [] }
  #      )
  #
  # In addition, a number of helper methods are defined:
  #
  # * Standard object methods: #==, #inspect
  # * Case checking predicates:
  #       some_validation.success?
  #       some_validation.failure?
  # * Functions for handling specific cases:
  #       some_validation.when_success(proc { |values| values }, proc { [] })
  #
  # @param [Proc] &definitions block which defines the constructors. This will be evaluated using
  #               #instance_eval to record the cases.
  #
  def cases(&definitions)
    dsl = CaseRecorder.new
    dsl.__instance_eval(&definitions)

    cases = dsl._church_cases
    num_cases = dsl._church_cases.length
    case_names = dsl._church_cases.map { |x| x[0] }

    # creates procs with a certain arg count. body should use aN to access arguments. The result should be
    # evalled at the call site
    proc_create = proc { |argc, prefix, body|
      args = argc > 0 ? "|#{(1..argc).to_a.map { |a| "#{prefix}#{a}" }.join(',')}|" : ""
      "proc { #{args} #{body} }" 
    }

    # Initializer. Should not be used directly.
    define_method(:initialize) do |&fold|
      @fold = fold
    end

    # The Fold.
    define_method(:fold) do |*args|
      if args.first && args.first.is_a?(Hash) then
        @fold.call(*case_names.map { |cn| args.first.fetch(cn) })
      else
        @fold.call(*args)
      end
    end

    # The Constructors
    dsl._church_cases.each_with_index do |(name, case_args), index|
      self.class.send(:define_method, name) do |*args|
        the_proc = eval(proc_create[num_cases, "a", "a#{index+1}.call(*args)"])
        self.new(&the_proc)
      end
    end

    # The usual object helpers
    define_method(:inspect) do
      "#<" + self.class.name + fold(*dsl._church_cases.map { |(cn, case_args)|
        index = 0
        bit = case_args.map { |ca| 
          index += 1
          " #{ca}:#\{a#{index}\}"
        }.join('')
        eval(proc_create[case_args.count, "a", " \" #{cn}#{bit}\""])
      }) + ">"
    end

    define_method(:==) do |other|
      !other.nil? && begin
        fold(*cases.map { |(cn, args)|
          inner_check = proc_create[args.count, "o", (1..(args.count)).to_a.map { |idx| "s#{idx} == o#{idx}"  }.<<("true").join(' && ')]
          eval(proc_create[args.count, "s", "other.when_#{cn}(#{inner_check}, proc { false })"])
        })
      end
    end

    # Case specific methods
    # eg.
    #     cases do foo(:a); bar(:b); end
    cases.each_with_index do |(name, args), idx|
      #     Thing.foo(5).foo? # <= true
      #     Thing.foo(5).bar? # <= false
      define_method("#{name}?") do
        fold(*case_names.map { |cn|
          eval(proc_create[0, "a", cn == name ? "true" : "false"])
        })
      end
      
      #     Thing.foo(5).when_foo(proc {|v| v }, proc { 0 }) # <= 5
      #     Thing.bar(5).when_foo(proc {|v| v }, proc { 0 }) # <= 0
      define_method("when_#{name}") do |handle, default|
        fold(*case_names.map { |cn| 
          if (cn == name)
           proc { |*args| handle.call(*args) }
          else
           default
          end
        })
      end
    end
  end
end

module Kernel
  # Returns a class configured with cases as specified in the block. See `ADT::cases` for details.
  #
  #     Maybe = ADT do
  #       just(:value)
  #       nothing
  #     end
  #
  #     v = Maybe.just(5)
  #  
  def ADT(&blk)
    c = Class.new
    c.instance_eval do
      extend ADT
      cases(&blk)
    end
    c
  end
end

