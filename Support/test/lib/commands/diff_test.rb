require File.dirname(__FILE__) + '/../../test_helper'

class TestDiffParsing < Test::Unit::TestCase
  include TestHelpers

  def setup
    @diff = Git.new
  end

  def test_should_create_an_entry_for_each_file
    results = @diff.parse_diff(fixture_file("changed_files.diff"))
    assert_equal 2, results.length
    assert_equal ["Support/lib/commands/diff.rb", "Support/lib/formatters/diff.rb"],
                 results.map { |r| r[:left][:file_path] }
    assert_equal ["Support/lib/commands/diff.rb", "Support/lib/formatters/diff.rb"],
                 results.map { |r| r[:right][:file_path] }
  end

  def test_should_parse_the_line_numbers_for_the_files
    results = @diff.parse_diff(fixture_file("changed_files.diff"))
    lines = results.first[:lines]

    expected_left = (5..7).to_a + [8] + ([nil] * 20) + (9..10).to_a + ["EOF"]
    expected_right = (5..7).to_a + [nil] + (8..27).to_a + (28..29).to_a + ["EOF"]

    assert_equal expected_left, lines.map { |l| l[:ln_left] }
    assert_equal expected_right, lines.map { |r| r[:ln_right] }
  end

  def test_should_not_count_no_newline_at_end_of_file_line
    results = @diff.parse_diff(fixture_file("changed_files.diff"))
    lines = results.first[:lines]
    assert_equal "No newline at end of file", lines.last[:text]
    assert_equal "EOF", lines.last[:ln_right]
    assert_equal "EOF", lines.last[:ln_left]
  end

  def test_should_parse_the_file_mode
    results = @diff.parse_diff(fixture_file("changed_files.diff"))
    assert_equal "100644", results.first[:mode]
  end
end

class TestDiffWithLineBreaks < Test::Unit::TestCase
  include TestHelpers

  def setup
    @diff = Git.new
  end

  def test_should_insert_a_line_break
    results = @diff.parse_diff(fixture_file("changed_files_with_break.diff"))
    lines = results.first[:lines]
    assert_includes lines.map { |t| t[:type] }, :cut
  end
end

class TestDiffNewLineAtEnd < Test::Unit::TestCase
  include TestHelpers

  def setup
    @diff = Git.new
  end

  def test_should_show_eof_for_the_side_with_line_numbers
    results = @diff.parse_diff(fixture_file("new_line_at_end.diff"))
    lines = results.first[:lines]
    eof_line = lines.find { |l| l[:type] == :eof }
    assert_equal "EOF", eof_line[:ln_left]
    assert_nil eof_line[:ln_right]
  end
end

class TestSmallDiff < Test::Unit::TestCase
  include TestHelpers

  def setup
    @diff = Git.new
  end

  def test_should_start_with_line_number_zero
    results = @diff.parse_diff(fixture_file("small.diff"))
    lines = results.first[:lines]
    assert_equal [1, "EOF", nil, nil, nil, nil], lines.map { |l| l[:ln_left] }
    assert_equal [nil, nil, 1, 2, 3, "EOF"], lines.map { |l| l[:ln_right] }
  end
end

class TestDiffNewAndDeletedFiles < Test::Unit::TestCase
  include TestHelpers

  def setup
    @diff = Git.new
  end

  def test_should_be_status_new_for_new_files
    results = @diff.parse_diff(fixture_file("submodules.diff"))
    assert_equal :new, results[0][:status]
  end

  def test_should_pick_up_mode_from_new_file_mode_line
    results = @diff.parse_diff(fixture_file("submodules.diff"))
    assert_equal "160000", results[0][:mode]
  end

  def test_should_be_status_deleted_for_deleted_files
    results = @diff.parse_diff(fixture_file("submodules.diff"))
    assert_equal :deleted, results[1][:status]
  end

  def test_should_pick_up_mode_from_deleted_file_mode_line
    results = @diff.parse_diff(fixture_file("submodules.diff"))
    assert_equal "160000", results[1][:mode]
  end
end
