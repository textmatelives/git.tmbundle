require File.dirname(__FILE__) + '/../../test_helper'
require 'stringio'

class TestPullFrom153 < Test::Unit::TestCase
  include TestHelpers

  def setup
    @pull = Git.new
    Git.reset_mock!
    Git.command_response["branch"] = "* master\n  task"

    @process_io = StringIO.new(<<-EOF)
Unpacking 6 objects...
 16% (1/6) done\r 33% (2/6) done\r 50% (3/6) done\r 66% (4/6) done\r 83% (5/6) done\r 100% (6/6) done\n
* refs/remotes/origin/master: fast forward to branch 'master' of /Users/timcharper/projects/origin
  old..new: a58264f..89e8f37
* refs/remotes/origin/mybranch: storing branch 'mybranch' of /Users/timcharper/projects/origin
  commit: d8b3683
You asked me to pull without telling me which branch you
want to merge with, and 'branch.asdf.merge' in
your configuration file does not tell me either.  Please
name which branch you want to merge on the command line and
try again (e.g. 'git pull <repository> <refspec>').
See git-pull(1) for details on the refspec.

If you often merge with the same branch, you may want to
configure the following variables in your configuration
file:
EOF
  end

  def test_should_call_the_status_proc_6_times
    started_count = {}
    finished = {}
    output = { "Unpacking" => [] }
    @pull.process_pull(@process_io,
      :start => lambda { |state, count| started_count[state] = count },
      :progress => lambda { |state, percent, index, count| output[state] << [percent, index, count] },
      :end => lambda { |state, count| finished[state] = true }
    )

    ["Unpacking"].each do |state|
      assert_equal 6, started_count[state]
      assert_equal [0, 16, 33, 50, 66, 83, 100], output[state].map { |o| o[0] }
      assert_equal (0..6).to_a, output[state].map { |o| o[1] }
      assert_equal [6] * 7, output[state].map { |o| o[2] }
      assert_equal true, finished[state]
    end
  end

  def test_should_return_a_list_of_all_revisions_pulled
    output = @pull.process_pull(@process_io)
    expected = {
      "refs/remotes/origin/master" => ["a58264f", "89e8f37"],
      "refs/remotes/origin/mybranch" => ["d8b3683^", "d8b3683"]
    }
    assert_equal expected, output[:pulls]
  end

  def test_should_return_nothing_to_pull_if_already_up_to_date
    output = @pull.process_pull(StringIO.new("Already up-to-date.\n"))
    assert_equal true, output[:nothing_to_pull]
  end
end

class TestPullFrom1543 < Test::Unit::TestCase
  include TestHelpers

  def setup
    @pull = Git.new
    Git.reset_mock!
    Git.command_response["branch"] = "* master\n  task"
    @process_io = StringIO.new(fixture_file("pull_1_5_4_3_output.txt"))
  end

  def test_should_call_progress_proc_6_times_for_compressing
    output = { "Compressing" => [] }
    @pull.process_pull(@process_io,
      :progress => lambda { |state, percent, index, count| output[state] << [percent, index, count] }
    )
    assert_equal [16, 33, 50, 66, 83, 100], output["Compressing"].map { |o| o[0] }
    assert_equal (1..6).to_a, output["Compressing"].map { |o| o[1] }
    assert_equal [6] * 6, output["Compressing"].map { |o| o[2] }
  end

  def test_should_extract_pull_information_for_the_branch
    output = @pull.process_pull(@process_io)
    assert_equal ["dc29d3d", "05f9ad9"], output[:pulls]['asdf']
    assert_equal ["791a587", "4bfc230"], output[:pulls]['master']
  end
end
