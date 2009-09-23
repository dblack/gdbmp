require 'test/unit'
require '../lib/gdbmp'
require 'stringio'

class GDBMPTest < Test::Unit::TestCase

  def setup
    @g = GDBMP.new("/tmp/g.out")
  end

  def test_integer_key_string_value
    @g[1] = "hi"
    assert_equal("hi", @g[1])
  end

  def test_string_key_integer_value
    @g["hi"] = 123
    assert_equal(123, @g["hi"])
  end

  def test_integer_key_float_value
    @g[1] = 1.23
    assert_equal(1.23, @g[1])
  end

  def test_float_key_integer_value
    @g[1.23] = 123
    assert_equal(123, @g[1.23])
  end

  def test_integer_key_symbol_value
    @g[10] = :abc
    assert_equal(:abc, @g[10])
  end

  def test_float_key_symbol_value
    @g[1.23] = :abc
    assert_equal(:abc, @g[1.23])
  end

  def test_string_key_symbol_value
    @g["def"] = :abc
    assert_equal(:abc, @g["def"])
  end

  def test_symbol_key_integer_value
    @g[:abc] = 123
    assert_equal(123, @g[:abc])
  end

  def test_a_bunch_of_data
    @g[2.34] = 1.23
    @g["hi"] = 123
    @g[123] = "hi"
    assert_equal(1.23, @g[2.34])
    assert_equal(123, @g["hi"])
    assert_equal("hi", @g[123])
  end

  def test_constrained_key_string
    @g.constrain_key(:abc, "String")
    @g[:abc] = 123
    assert_equal("123", @g[:abc])
  end

  def test_constrained_key_float
    @g.constrain_key(:abc, "Float")
    @g[:abc] = 123
    assert_equal(123.0, @g[:abc])
    @g[:abc] = "12.3"
    assert_equal(12.3, @g[:abc])
  end

  def test_constrained_key_symbol
    @g.constrain_key(:def, "Symbol")
    @g[:def] = 123
    assert_equal(:"123", @g[:def])
  end

  def test_warn_on_unconvertible_key
    s = StringIO.new
    $stderr = s
    obj = Object.new
    @g[obj] = 1
    assert_match(/Warning.*Object/, s.string)
    s.rewind
    @g[obj]
    assert_match(/Warning.*Object/, s.string)
    $stderr = STDERR
  end

  def test_warn_on_unconvertible_value
    s = StringIO.new
    $stderr = s
    obj = Object.new
    @g[1] = obj
    assert_match(/Warning.*Object/, s.string)
    $stderr = STDERR
  end

  def test_class_level_constrained_keys
    child = Class.new(GDBMP)
    child.constrain_key(:age, Fixnum)
    c = child.new("/tmp/child.gdbm")
    c[:age] = "30"
    assert_equal(30, c[:age])
  end

  def test_iteration
    @g[123] = "hi"
    @g[:abc] = 1.2
    @g.each do |k,v|
      assert([123,:abc].include?(k))
      assert(["hi", 1.2].include?(v))
    end
  end

  def teardown
    @g.close
    File.unlink("/tmp/g.out")
  end

end

