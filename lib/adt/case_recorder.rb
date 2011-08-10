module ADT
  class CaseRecorder
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
end
