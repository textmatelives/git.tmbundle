require File.dirname(__FILE__) + '/../../test_helper'

class TestLogParsing < Test::Unit::TestCase
  include TestHelpers

  def setup
    @git = Git.new
  end

  def test_should_parse_out_all_items
    entries = @git.parse_log(fixture_file('log.txt'))
    assert_equal 5, entries.length
  end

  def test_should_parse_out_the_author_msg_and_revision
    entries = @git.parse_log(fixture_file('log.txt'))
    result = entries.first
    assert_equal "2762e1264c439dced7f05eacd33fc56499b8b779", result[:rev]
    assert_equal "Tim Harper <timcharper@domain.com>", result[:author]
    assert_equal Time.parse("Mon Feb 4 07:51:25 2008 -0700"), result[:date]
    expected_msg = %Q{bugfix - diff was not parsing the index line sometimes because it varies on deleted files\n\nmade more failproof}
    assert_equal expected_msg, result[:msg]
  end
end

class TestLogWithDiffs < Test::Unit::TestCase
  include TestHelpers

  def setup
    @git = Git.new
  end

  def test_should_extract_and_parse_diffs
    entries = @git.parse_log(fixture_file("log_with_diffs.txt"))
    entry = entries.first
    refute_nil entry[:diff]
    entry_diff = entry[:diff].first
    assert_equal "Commands/Browse Annotated File (blame).tmCommand", entry_diff[:left][:file_path]
    assert_equal "Commands/Browse Annotated File (blame).tmCommand", entry_diff[:right][:file_path]
    assert_equal 19, entry_diff[:lines].length
  end
end
