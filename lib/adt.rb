require 'adt/case_recorder'

module StringHelp
  def self.underscore(camel_cased_word)
    word = camel_cased_word.to_s.dup
    word.gsub!(/::/, '/')
    word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.tr!("-", "_")
    word.downcase!
    word
  end
end

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
  # * Conversion to an array of the arguments: #to_a (nullary constructors return empty arrays)
  # * #<=> and Comparable: cases are compared by index, and then by their parameters as an array
  # * Case checking predicates:
  #       some_validation.success?
  #       some_validation.failure?
  # * Functions for handling specific cases:
  #       some_validation.when_success(proc { |values| values }, proc { [] })
  # * Case information
  #       some_validation.case_name # <= "success"
  #       some_validation.case_index # <= 1 # Indexing is 1-based.
  #       some_validation.case_arity # <= 1 # Number of arguments required by the case
  # * #fold is aliased to an underscored name of the type. ie. ValidatedValue gets #validated_value
  #
  # If the type is an enumeration (it only has nullary constructors), then a few extra methods are available:
  # 
  # * 1-based conversion to and from integers: #to_i, ::from_i
  # * Accessor for all values: ::all_values
  #
  #
  # @param [Proc] &definitions block which defines the constructors. This will be evaluated using
  #               #instance_eval to record the cases.
  #
  def cases(&definitions)
    singleton_class = class <<self; self; end
    dsl = CaseRecorder.new
    dsl.__instance_eval(&definitions)

    cases = dsl._church_cases
    num_cases = dsl._church_cases.length
    case_names = dsl._church_cases.map { |x| x[0] }
    is_enumeration = dsl._church_cases.all?{ |(_, args)| args.count == 0 }

    # creates procs with a certain arg count. body should use #{prefix}N to access arguments. The result should be
    # eval'ed at the call site
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

    # If we're inside a named class, then set up an alias to fold
    fold_synonym = StringHelp.underscore(name.split('::').last)
    if fold_synonym && fold_synonym.length > 0 then
      define_method(fold_synonym) do |*args| fold(*args) end
    end

    # The Constructors
    dsl._church_cases.each_with_index do |(name, case_args), index|
      constructor = proc { |*args| self.new(&eval(proc_create[num_cases, "a", "a#{index+1}.call(*args)"])) }
      if case_args.size > 0 then
        singleton_class.send(:define_method, name, &constructor)
      else
        # Cache the constructed value if it is unary
        singleton_class.send(:define_method, name) do
          instance_variable_get("@#{name}") || begin
            instance_variable_set("@#{name}", constructor.call)
          end
        end
      end
    end

    # Case info methods
    # Indexing is 1-based
    define_method(:case_index) do fold(*(1..case_names.length).to_a.map { |i| proc { i } }) end
    define_method(:case_name) do fold(*case_names.map { |i| proc { i.to_s } }) end
    define_method(:case_arity) do fold(*dsl._church_cases.map { |(_, args)| proc { args.count } }) end

    # Enumerations are defined as classes with cases that don't take arguments. A number of useful
    # functions can be defined for these.
    if is_enumeration 
      singleton_class.send(:define_method, :all_values) do
        @all_values ||= case_names.map { |x| send(x) }
      end

      define_method(:to_i) { case_index }
      singleton_class.send(:define_method, :from_i) do |idx| send(case_names[idx - 1]) end
    end

    # The usual object helpers
    define_method(:inspect) do
      "#<" + self.class.name + fold(*dsl._church_cases.map { |(cn, case_args)|
        index = 0
        bit = case_args.map { |ca| 
          index += 1
          " #{ca}:#\{a#{index}\.inspect}"
        }.join('')
        eval(proc_create[case_args.count, "a", " \" #{cn}#{bit}\""])
      }) + ">"
    end

    define_method(:==) do |other|
      !other.nil? && case_index == other.case_index && to_a == other.to_a
    end

    define_method(:to_a) do 
      fold(*cases.map { |(cn, args)|
        eval(proc_create[args.count, "a", "[" + (1..args.count).to_a.map { |idx| "a#{idx}" }.join(',') + "]"])
      })
    end

    # Comparisons are done by index, then by the values within the case (if any) via #to_a
    define_method(:<=>) do |other|
      comp = case_index <=> other.case_index
      comp == 0 ?  to_a <=> other.to_a : comp
    end
    include Comparable

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

  # Defines an operation (method) for an ADT, using a DSL similar to the cases definition.
  # 
  # For each case in the adt, the block should call a method of the same name, and pass it
  # a block argument that represents the implementation of the operation for that case.
  # 
  # eg. To define an operation on a Maybe/Option type which returns the wrapped value, or 
  # the supplied argument if it doesn't have anything:
  # 
  #     class Maybe
  #       extend ADT
  #       cases do
  #         just(:value)
  #         nothing
  #       end
  #
  #       operation :or_value do |if_nothing|
  #         just { |value| value }
  #         nothing { if_nothing }
  #       end
  #     end
  #
  #
  # @param [Symbol] The name of the operations to define.
  # @param [Proc] The definitions of the implementations for each case.
  def operation(sym, &definitions)
    define_method(sym) do |*args|
      the_instance = self
      dsl = CaseRecorder.new
      # The definitions block needs to be executed in the context of the recorder, to
      # read the impls.
      dsl.__instance_exec(*args, &definitions)
      # Now we just turn the [(case_name, impl)] structure into an argument for fold and
      # are done. Fold with a hash will check that all keys are defined.
      fold(dsl._implementations.inject({}) { |memo, (c, impl)| 
        # Fucker. if 'impl' is used directly, because of the 'define_method' from earlier,
        # it is evaluated in the context of the recorder, which is bad. So instead. We
        # instance_exec it back on the instance.
        # TODO: use the proc builder like in the `cases` method, which will let us tie 
        # down the arity
        some_impl = proc { |*args| the_instance.instance_exec(*args, &impl) }
        memo[c] = some_impl
        memo 
      })
    end
  end
end

