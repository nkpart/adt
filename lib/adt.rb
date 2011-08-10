module Kernel
  def ADT(&blk)
    c = Class.new
    c.instance_eval do
      extend ADT
      cases(&blk)
    end
    c
  end
end

module ADT
  module_function

  class ChurchDSL
    alias :__instance_eval :instance_eval

    instance_methods.each { |m| undef_method m unless m =~ /(^__|object_id)/ }

    attr_reader :_church_cases

    def initialize
      @_church_cases = []
    end

    def define_case(sym, *args)
      @_church_cases << [sym, args]
    end

    def method_missing(sym, *args)
      define_case(sym, *args)
    end
  end

  def cases(&defns)
    dsl = ChurchDSL.new
    dsl.__instance_eval(&defns)

    cases = dsl._church_cases
    num_cases = dsl._church_cases.length
    case_names = dsl._church_cases.map { |x| x[0] }

    # creates procs with a certain arg count. body should use aN to access arguments. The result should be
    # evalled at the call site
    proc_create = proc { |argc, prefix, body|
      args = argc > 0 ? "|#{(1..argc).to_a.map { |a| "#{prefix}#{a}" }.join(',')}|" : ""
      "proc { #{args} #{body} }" 
    }

    # Initializer. Should be private.
    define_method(:initialize) do |&fold|
      @fold = fold
    end

    # The Fold
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

    # TODO
    #  * #equals
    #  * #hash
  end
end

