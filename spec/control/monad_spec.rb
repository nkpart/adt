require 'adt'
require 'data/maybe'

class ValidationNEL
  extend ADT
  cases do
    failure(:errors)
    success(:value)
  end
end

module Control
  module U
    module_function
    def define(impls = {})
      x = Object.new
      meta = class<<x; self; end
      meta_meta = class<<meta; self; end
      meta_meta.send(:public, :define_method)
      yield meta
      impls.each do |method,impl|
        meta.define_method(method, &impl)
      end
      meta_meta.send(:private, :define_method)
      x
    end

    def inherit(parent, child)
      parent.methods(false).each do |m|
        child.send(:define_method, m) { |*args| parent.send(m, *args) }
      end
    end
  end

  def self.Monad(r, b, overrides = {})
    U.define(overrides) do |meta|
      meta.define_method(:return, &r)
      meta.define_method(:bind, &b)
      meta.define_method(:fmap) do |ma, f|
        bind(ma, ->(x) { self.return(f.(x)) })
      end
    end
  end

  def self.Functor(f, overrides = {})
    U.define(overrides) do |meta|
      meta.define_method(:fmap, f)
    end
  end

  def self.Applicative(functor, pure, starry, overrides = {})
    U.define(overrides) do |meta|
      meta.define_method(:pure, &pure)
      # (<*>) :: f (a -> b) -> f a -> f b
      meta.define_method(:starry, &starry)
      U.inherit(functor, meta)
    end
  end

  module Functor
    MaybeFunctor = Control::Functor(->(ma, f) { ma.map(&f) })
  end

  module Applicative
    MaybeApplicative = Control::Applicative(
      Functor::MaybeFunctor,
      Maybe.method(:just),
      ->(ff, fa) {
        m = Monad::MaybeMonad
        m.bind(ff, ->(f) {
          m.fmap(fa, f)
        })
      }
    )
  end

  module Monad
    MaybeMonad = Control::Monad(
      Maybe.method(:just),
      ->(x, f) { x.fold(nothing: -> { x }, just: ->(v) { f.(v) }) }
    )

    ListMonad = Control::Monad(
      ->(x) { [x] },
      ->(x, f) { x.inject([]) { |m, v| m + f.(v) } },
      fmap: ->(xs, f) { xs.map(&f) }
    )

    LambdaMonad = Control::Monad(
      ->(x) { ->(v) { x } },
      ->(x, f2my) { ->(v) { f2my.(x.(v)).(v) } }
    )
  end

  include Monad
  include Applicative

  # ap :: Monad m => m (a -> b) -> m a -> m b
  def self.ap(monad); lambda do |mf, ma|
    monad.instance_eval do
      bind(mf, ->(f) {
        bind(ma, ->(a) {
          self.return(f.(a))
        })
      })
    end
  end; end

  # sequence :: Monad m => [m a] -> m [a]
  def self.sequence(monad); lambda do |ma|
    ma.inject(monad.return([])) { |m, v|
      monad.bind(m, ->(accum) {
        monad.fmap(v, ->(this_v) { accum << this_v })
      })
    }
  end; end
end

describe Control do
  it {
    f = Maybe.just(->(x) { x + 1 })
    v = Maybe.just(3)
    Control.ap(Control::MaybeMonad).(f, v).should == Maybe.just(4)

    f = [->(x) { x + 1}, ->(x) { x - 1 }]
    v = [2, 3]
    Control.ap(Control::ListMonad).(f, v).should == [3, 4, 1, 2]

    f = ->(x) { ->(y) { x + y } }
    v = ->(x) { x - 2 }
    Control.ap(Control::LambdaMonad).(f, v).(7).should == 12
  }

  it {
    Control::ListMonad.fmap([1,2,3], ->(x) { x + 1 }).should == [2,3,4]
    Control::MaybeMonad.fmap(Maybe.just(1), ->(x) { x + 1 })
  }

  it {
    Control.sequence(Control::MaybeMonad).([Maybe.just(1), Maybe.just(2)]).should == Maybe.just([1,2])
  }

  it {
    f = Maybe.just(->(x) { x + 1 })
    v = Maybe.just(1)
    Control::MaybeApplicative.starry(f, v).should == Maybe.just(2)
  }

  it {
    functor = Control.Functor(->(v, f) {
      v.fold(failure: ->(es) { ValidationNEL.failure(es) },
             success: ->(v) { ValidationNEL.success(f.(v)) })
    })
    applicative = Control.Applicative(functor,
                                      ValidationNEL.method(:success),
                                      ->(ff, fa) {
                                        ff.fold(
                                          failure: ->(es) {
                                            fa.fold(
                                              failure: ->(es2) { ValidationNEL.failure(es + es2) },
                                              success: ->(v) { ff }
                                            )
                                          },
                                          success: ->(f) {
                                            fa.fold(
                                              failure: ->(es2) { fa },
                                              success: ->(a) { ValidationNEL.success(f.(a)) }
                                            )
                                          })
                                      })

    e1 = ValidationNEL.failure([1, 2])
    e2 = ValidationNEL.failure([3])
    applicative.starry(e1, e2).should == ValidationNEL.failure([1, 2, 3])
  }
end
