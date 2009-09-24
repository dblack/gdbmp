# GDBMP -- GDBM with some class-recognition intelligence
#
# by David A. Black
# and incorporating a major implementation suggestion from Aaron Patterson
#
# September 2009
#
# Copyright (c) 2009, Ruby Power and Light, LLC
# Released under the same license as Ruby.
#
# Use at your own risk.
#
#
# ==Overview
#
# GDBMP (and in all seriousness, I can't remember why I chose "P") is a subclass
# of Ruby's GDBM class, adding the ability to save keys and values that are of
# other classes than String. It does this using Marshal. (This was not the
# original way; it was a modification suggested by Aaron Patterson. See History,
# below.) 
#
# Examples:
#
#   g = GDBMP.new("myfile.gdbm")
#   g[:abc] = 1.2
#   g[123] = "hi"
#   g[1.23] = :symbol
#
#   p g[:abc]   # => 1.2
#   p g[123]    # => "hi"
#
# etc.
#
#
# == Constraining keys to classes
#
# You might want to force the value for a certain key to be of a particular
# class. For example, if you get form input consisting of strings, you might
# want your database to know that some of the strings should be stored as
# integers. 
#
# You can do that with the constrain_key method. Using this method, you register
# certain keys along with the desired classes for their values. 
#
#   g.constrain_key(:year, Fixnum)
#   g[:year] = "1999"
#
#   p g[:year]  # 1999 (the integer, not the string)
#
# The class you constrain a key to has to be represented in the converters hash,
# GDBMP::CONVERTERS. 
#
# You can also add these constraints at the class level:
#
#   class Person < GDBMP
#     constrain_key(:age, Fixnum)
#     # etc.
#   end
#
# On initialization, each instance of the class will pick up the class's constrained
# keys. 
#
# == History
#
# This library grew from some experiments I was doing involving ActiveModel,
# which is part of Rails 3.0 (currently in development). I was playing with the
# ActiveModel API which makes it relatively easy to create entire new backends,
# relational or otherwise, for ActiveRecord. 
#
# Aside from just getting GDBM to deal with things other than strings, the main
# issue was the need to register specific classes with specific keys -- which
# became constrain_key. 
#
# Originally I was doing the data storage and conversion by saving names of
# classes to the database along with the data. Aaron Patterson suggested using
# Marshal instead. The problem I saw at first was that there was still a need to
# do the key constraining by class. However... that kind of solved itself, since
# as long as the data is marshaled in the correct class, it will be saved and
# retrieved in the correct class. 

require 'gdbm'

class GDBMP < GDBM

# Functionality for constraining keys to particular classes, so that the values for
# those keys will always be converted to those classes. It's available at the
# class and instance levels. 
  module KeyBinder
    def constrained_keys
      @constrained_keys ||= {}
    end

    def constrain_key(key, klass)
      constrained_keys[key] = klass.to_s
    end
  end

  include KeyBinder
  extend KeyBinder

  CONVERTERS = {  "String" => lambda {|val| val.to_s },
                  "Fixnum" => lambda {|val| val.to_i },
                  "Float"  => lambda {|val| val.to_f },
                  "Symbol" => lambda {|val| val.to_s.to_sym } }


# On initialization, create the constrained keys hash
  def initialize(*args, &block)
    constrained_keys.update(self.class.constrained_keys)
    super
  end

# On setting an entry, convert the value if it's a constrained key. Then prep
# the key and value to make sure they have their class names. 
  def []=(key, val)
    target_klass = constrained_keys[key]
    val = CONVERTERS[target_klass].call(val) if target_klass
    super(prep(key), prep(val))
  end

# Retrieval. Prep the key ("Symbol:abc"), get the value, and convert it based on
# the class. 
  def [](key)
    convert(super(prep(key)))
  end

# GDBM objects are enumerable. This override of each ensures that the iteration
# for GDBMP respects the conversions. 
  def each
    super do |key, value|
      yield(convert(key), convert(value))
    end
  end

private

# Take a prepped string ("Symbol:abc") and convert the value based on the class. 
  def convert(string)
 #   vclass, val = string.split(':', 2)
 #   CONVERTERS[vclass].call(val)
    Marshal.load(string)
  end

# Turn (e.g.) 123 into "Fixnum:123". Warn if the object's class doesn't have a
# built-in converter. 
  def prep(obj)
  #  obj_class = obj.class.to_s
  #  unless CONVERTERS[obj_class]
  #    warn "Warning: can't convert #{obj_class}; treating as string"
  #  end
    Marshal.dump(obj)
  end
end
