# GDBMP -- GDBM with some class-recognition intelligence
#
# David A. Black
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
# other classes than String. It does this by saving a class name along with the
# keys and values and, on retrieval, performing the necessary conversions to
# recognize the keys and prepare the values. 
#
# Examples:
#
#   g = GDBMP.new("myfile.gdbm")
#   g[:abc] = 1.2
#   g[123] = "hi"
#   g[1.23] = :symbol
#
# At this point, the actual entries in the database are:
#
#   [["Fixnum:123", "String:hi"], ["Symbol:abc", "Float:1.2"],
#    ["Float:1.23", "Symbol:symbol"]]
#
# When you retrive the values, though, the conversions are taken care of:
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
# == Unknown conversions
#
# The conversion mechanism can only handle the classes that are in the
# converters hash. If you use an object of a different class, it may well work,
# but you'll get a warning.
#
# For example:
#
#   obj = Object.new
#   g[obj] = 123
#     Warning: can't convert Object; treating as string
#
# Now you'll have this entry in the database:
#
#   ["Object:#<Object:0x240798>", "Fixnum:123"]
#
# You can retrieve the key using <tt>obj</tt>, but only because <tt>obj</tt>
# supplies the same string both times it's "prepped" by GDBMP. So it kind of
# works by coincidence. In general, it's probably best to stick to the four
# classes for which converters are provided.

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
    vclass, val = string.split(':', 2)
    CONVERTERS[vclass].call(val)
  end

# Turn (e.g.) 123 into "Fixnum:123". Warn if the object's class doesn't have a
# built-in converter. 
  def prep(obj)
    obj_class = obj.class.to_s
    unless CONVERTERS[obj_class]
      warn "Warning: can't convert #{obj_class}; treating as string"
    end
    "#{obj.class}:#{obj}"
  end
end
