require 'adt/case_recorder'

module AdtUtils
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

def ADT(&block)
  m = Module.new
  m.class.send(:public, :define_method)
  (class <<m; self end).define_method(:extended) do |base|
      base.extend(ADT)
      base.send(:cases, &block)
  end
  m
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
  # This will provide 2 core pieces of functionality.
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
    case_names = cases.map { |x| x[0] }
    is_enumeration = cases.all? { |(_, args)| args.count == 0 }

    # Initializer. Should not be used directly.
    define_method(:initialize) do |tag, tag_index, values|
      @tag = tag
      @tag_index = tag_index
      @values = values
    end

    # The Fold.
    define_method(:fold) do |*args|
      if args.first && args.first.is_a?(Hash) then
        args.first[@tag].call(*@values)
      else
        args[@tag_index].call(*@values)
      end
    end

    # If we're inside a named class, then set up an alias to fold
    fold_synonym = name && AdtUtils.underscore(name.split('::').last)
    if fold_synonym && !fold_synonym.empty? then
      alias_method(fold_synonym, :fold)
    end

    # The Constructors
    cases.each_with_index do |(name, case_args), index|
      constructor = lambda { |*args| self.new(name, index, args) }
      if case_args.size > 0 then
        singleton_class.send(:define_method, name, &constructor)
      else
        # Cache the constructed value if it is unary
        singleton_class.send(:define_method, name) do
          instance_variable_get("@#{name}") || begin
            instance_variable_set("@#{name}", self.new(name, index, []))
          end
        end
      end
    end

    # Case info
    singleton_class.send(:define_method, :case_info) { cases }

    # Getter methods for common accessors
    all_arg_names = cases.map { |(_, args)| args }.flatten
    all_arg_names.each do |arg|
      case_positions = cases.map { |(_, args)| args.index(arg) }
      if case_positions.all?
        define_method(arg) { 
          @values[case_positions[@tag_index]]
        }
      end
    end

    # Case info methods
    # Indexing is 1-based
    define_method(:case_index) { @tag_index + 1 }
    define_method(:case_name) { @tag.to_s }
    define_method(:case_arity) { self.class.case_info[@tag_index][1].count }

    # Enumerations are defined as classes with cases that don't take arguments. A number of useful
    # functions can be defined for these.
    if is_enumeration 
      singleton_class.send(:define_method, :all_values) do
        @all_values ||= case_names.map { |x| send(x) }
      end

      alias_method(:to_i, :case_index)
      singleton_class.send(:define_method, :from_i) do |idx| send(case_names[idx - 1]) end
      singleton_class.send(:define_method, :from_i) do |idx| send(case_names[idx - 1]) end
      #TODO succ, pred
    end

    # The usual object helpers
    define_method(:inspect) do
      args = self.class.case_info[@tag_index][1]
      "#<#{self.class.name} #{@tag}#{args.zip(@values).map { |(x,y)| " #{x}:#{y.inspect}" }.join("")}>"
    end

    define_method(:==) do |other|
      !other.nil? && case_index == other.case_index && to_a == other.to_a
    end

    define_method(:to_a) { @values }

    # Comparisons are done by index, then by the values within the case (if any) via #to_a
    define_method(:<=>) do |other|
      comp = case_index <=> other.case_index
      comp == 0 ?  to_a <=> other.to_a : comp
    end
    include Comparable

    # Case specific methods
    # eg.
    #     cases do foo(:a); bar(:b); end
    cases.each_with_index do |(name, _), idx|
      #     Thing.foo(5).foo? # <= true
      #     Thing.foo(5).bar? # <= false
      define_method("#{name}?") { @tag == name }
      
      #     Thing.foo(5).when_foo(proc {|v| v }, proc { 0 }) # <= 5
      #     Thing.bar(5).when_foo(proc {|v| v }, proc { 0 }) # <= 0
      define_method("when_#{name}") do |handle, default|
        @tag == name ? handle.call(*@values) : default.call
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
        some_impl = lambda { |*as| the_instance.instance_exec(*as, &impl) }
        memo[c] = some_impl
        memo 
      })
    end
  end
end

