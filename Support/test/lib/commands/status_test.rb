require File.dirname(__FILE__) + '/../../test_helper'

class TestStatus < Test::Unit::TestCase
  include TestHelpers

  def setup
    @git = Git.new
    Git.reset_mock!
    Git.command_response["status", "--porcelain"] = fixture_file("status_output.txt")
  end

  def test_should_return_initial_commit_pending_as_false
    assert_equal false, @git.initial_commit_pending?
  end

  def test_should_return_initial_commit_pending_as_true
    Git.command_response["status"] = <<EOF
# On branch master
#
# Initial commit
#
nothing to commit (create/copy files and use "git add" to track)
EOF
    assert_equal true, @git.initial_commit_pending?
  end

  def test_should_parse_and_return_sorted_list_of_statuses
    results = @git.status
    expected_paths = [
      "/base/app/views/layouts/application.html.erb",
      "/base/dir/",
      "/base/directory.txt",
      "/base/new_file_and_added.txt",
      "/base/project.txt",
      "/base/small.diff"
    ]
    assert_equal expected_paths, results.map { |r| r[:path] }
  end

  def test_should_parse_appropriate_statuses
    results = @git.status
    assert_equal ["R", "?", "?", "A", "M", "D"], results.map { |r| r[:status][:short] }
  end

  def test_should_filter_to_a_folder
    results = @git.status("/base/dir")
    assert_equal ["/base/dir/"], results.map { |r| r[:path] }
  end

  def test_should_filter_to_a_file
    results = @git.status("/base/small.diff")
    assert_equal ["/base/small.diff"], results.map { |r| r[:path] }
  end

  def test_should_filter_to_a_subfolder
    results = @git.status("/base/app/views/layouts")
    assert_equal 1, results.length
    result = results.first
    assert_equal "/base/app/views/layouts/application.html.erb", result[:path]
    assert_equal "app/views/layouts/application.html.erb", result[:display]
  end

  def test_should_parse_a_status_document_correctly
    result = @git.parse_status_hash(fixture_file("status_output.txt"))
    expected = {
      "dir/" => "?",
      "new_file_and_added.txt" => "A",
      "small.diff" => "D",
      "directory.txt" => "?",
      "project.txt" => "M",
      "app/views/layouts/application.html.erb" => "R"
    }
    assert_equal expected, result
  end

  def test_should_recognize_conflict_markers
    assert_equal true, @git.file_has_conflict_markers("#{FIXTURES_DIR}/conflict.txt")
    assert_equal false, @git.file_has_conflict_markers("#{FIXTURES_DIR}/log.txt")
  end
end
