#!/usr/bin/env ruby

require 'rubygems'
require 'tempfile'
require 'test/unit'
require '../lib/xz'

TEST_XZ = "\3757zXZ\000\000\004\346\326\264F\002\000!\001\026\000\000\000t/" +
  "\345\243\340\000\023\000\020]\000\030\fB\222jg\274\016\32132a\326|\000\000" +
  "\000\017:\376\373\"1\270\266\000\001,\024\370\nm\003\037\266\363}\001\000" +
  "\000\000\000\004YZ"

class TestXZ < Test::Unit::TestCase
  def test_decompress
    assert_equal(XZ.decompress(TEST_XZ), '01234567890123456789')
  end

  def test_compress
    tmp = XZ.compress('01234567890123456789')
    assert_equal(tmp[0, 5].bytes.to_a, "\3757zXZ".bytes.to_a)
  end

  def test_compress_file
    infile = Tempfile.new('in')
    infile.write('01234567890123456789')
    infile.close

    outfile = Tempfile.new('out')
    outfile.close

    XZ.compress_file(infile.path, outfile.path)

    outfile.open
    assert_equal(outfile.read[0, 5].bytes.to_a, "\3757zXZ".bytes.to_a)
    outfile.close

    infile.delete
    outfile.delete
  end

  def test_decompress_file
    infile = Tempfile.new('in')
    infile.write(TEST_XZ)
    infile.close

    outfile = Tempfile.new('out')
    outfile.close

    XZ.decompress_file(infile.path, outfile.path)

    outfile.open
    assert_equal(outfile.read, '01234567890123456789')
    outfile.close

    infile.delete
    outfile.delete
  end
end

