require File.dirname(__FILE__) + '/../test_helper'
require LIB_ROOT + "/partial_commit_worker"

class TestPartialCommitWorkerNormal < Test::Unit::TestCase
  include TestHelpers

  def setup
    @git = Git.new
    Git.reset_mock!
    @commit_worker = PartialCommitWorker::Normal.new(@git)
  end

  def test_should_not_be_ok_to_proceed_when_not_on_a_branch_and_not_initial_commit
    @git.branch.define_singleton_method(:current_name) { |*_args| nil }
    @git.define_singleton_method(:initial_commit_pending?) { false }
    @git.define_singleton_method(:rebase_in_progress?) { false }
    assert_equal false, @commit_worker.ok_to_proceed_with_partial_commit?
  end

  def test_should_be_ok_to_proceed_when_not_on_a_branch_but_initial_commit
    @git.branch.define_singleton_method(:current_name) { |*_args| nil }
    @git.define_singleton_method(:initial_commit_pending?) { true }
    @git.define_singleton_method(:rebase_in_progress?) { false }
    assert_equal true, @commit_worker.ok_to_proceed_with_partial_commit?
  end

  def test_should_not_be_ok_to_process_when_no_file_candidates
    @commit_worker.define_singleton_method(:file_candidates) { [] }
    assert_equal true, @commit_worker.nothing_to_commit?
  end

  def test_should_not_send_last_commit_message_to_commit_window_when_committing
    @git.define_singleton_method(:log) { |*_args| [{:msg => "My Message"}] }
    @commit_worker.define_singleton_method(:file_candidates) { [] }
    @commit_worker.define_singleton_method(:status_helper_tool) { "/path/to/status_helper_tool" }
    output = @commit_worker.tm_scm_commit_window
    refute_includes output, Shellwords.escape("My Message")
  end
end

class TestPartialCommitWorkerAmend < Test::Unit::TestCase
  include TestHelpers

  def setup
    @git = Git.new
    Git.reset_mock!
    @commit_worker = PartialCommitWorker::Amend.new(@git)
  end

  def test_should_not_be_ok_to_proceed_when_initial_commit
    @git.define_singleton_method(:initial_commit_pending?) { true }
    assert_equal true, @commit_worker.nothing_to_amend?
  end

  def test_should_be_ok_to_amend_if_no_file_candidates
    @commit_worker.define_singleton_method(:file_candidates) { [] }
    assert_equal false, @commit_worker.nothing_to_commit?
  end

  def test_should_send_last_commit_message_to_commit_window_when_amending
    @git.define_singleton_method(:log) { |*_args| [{:msg => "My Message"}] }
    @commit_worker.define_singleton_method(:file_candidates) { [] }
    @commit_worker.define_singleton_method(:status_helper_tool) { "/path/to/status_helper_tool" }
    output = @commit_worker.tm_scm_commit_window
    assert_includes output, Shellwords.escape("My Message")
  end
end
