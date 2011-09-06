module ADT
  # @private
  class CaseRecorder
    alias :__instance_eval :instance_eval
    alias :__instance_exec :instance_exec
    instance_methods.each { |m| undef_method m unless m =~ /(^__|object_id)/ }

    def initialize
      @tape = []
    end

    def _church_cases
      @tape.map { |xs| xs[0..1] }
    end

    def _implementations
      # Implementations have a symbol and a block argument
      @tape.map { |xs| [xs[0], xs[2]] }
    end

    # Defines a case for an ADT.
    def define_case(sym, *args)
      record(sym, *args)
    end
    
    private

    def record(sym, *args, &blk)
      @tape << [sym, args, blk]
    end

    # Records EVERYTHING
    def method_missing(sym, *args, &blk)
      record(sym, *args, &blk)
    end
  end
end
