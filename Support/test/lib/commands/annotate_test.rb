require File.dirname(__FILE__) + '/../../test_helper'

class TestAnnotateParsing < Test::Unit::TestCase
  include TestHelpers

  def setup
    @annotate = Git.new
  end

  def test_should_parse_out_all_items
    lines = @annotate.parse_annotation(File.read("#{FIXTURES_DIR}/annotate.txt"))
    assert_equal 428, lines.length
  end

  def test_should_parse_out_the_author_msg_and_revision
    lines = @annotate.parse_annotation(File.read("#{FIXTURES_DIR}/annotate.txt"))
    line = lines.first
    assert_equal "26e2d189", line[:rev]
    assert_nil line[:filepath]
    assert_equal "Tim Harper", line[:author]
    assert_equal Time.parse("2008-03-02 00:24:40 -0700"), line[:date]
    assert_equal 'require LIB_ROOT + "/parsers.rb"', line[:text]
  end

  def test_renamed_should_parse_out_all_items
    lines = @annotate.parse_annotation(File.read("#{FIXTURES_DIR}/annotate_renamed.txt"))
    assert_equal 428, lines.length
  end

  def test_renamed_should_parse_out_the_author_msg_and_revision
    lines = @annotate.parse_annotation(File.read("#{FIXTURES_DIR}/annotate_renamed.txt"))
    line = lines.first
    assert_equal "26e2d189", line[:rev]
    assert_equal "Support/lib/git.rb", line[:filepath]
    assert_equal "Tim Harper", line[:author]
    assert_equal Time.parse("2008-03-02 00:24:40 -0700"), line[:date]
    assert_equal 'require LIB_ROOT + "/parsers.rb"', line[:text]
  end
end
