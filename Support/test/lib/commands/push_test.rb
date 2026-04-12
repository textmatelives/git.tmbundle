require File.dirname(__FILE__) + '/../../test_helper'
require 'stringio'

class TestPushStandard < Test::Unit::TestCase
  include TestHelpers

  def setup
    @push = Git.new
    @push.version = "1.5.3"

    @process_io = StringIO.new(<<-EOF)
updating 'refs/heads/mybranch'
  from f0f27c95b7cdf4ca3b56ecb3c54ef3364133eb6a
  to   d8b368361ebdf2c51b78f7cfdae5c3044b23d189
 Also local refs/remotes/satellite/mybranch
updating 'refs/heads/satellite'
  from 60a254470cd97af3668ed4d6405633af850139c6
  to   746fba2424e6b94570fc395c472805625ab2ed25
 Also local refs/remotes/satellite/satellite
Generating pack...
Done counting 6 objects.
Deltifying 6 objects...
  16% (1/6) done\r 33% (2/6) done\r 50% (3/6) done\r 66% (4/6) done\r 83% (5/6) def done(args)

  end
  \r 100% (6/6) done\n
Writing 6 objects...
  16% (1/6) done\r 33% (2/6) done\r 50% (3/6) done\r 66% (4/6) done\r 83% (5/6) done\r 100% (6/6) done\n
Total 6 (delta 1), reused 0 (delta 0)
refs/heads/satellite: 60a254470cd97af3668ed4d6405633af850139c6 -> 746fba2424e6b94570fc395c472805625ab2ed25
refs/heads/mybranch: f0f27c95b7cdf4ca3b56ecb3c54ef3364133eb6a -> d8b368361ebdf2c51b78f7cfdae5c3044b23d189
EOF
  end

  def test_should_call_the_status_proc_6_times
    started_count = {}
    finished = {}
    output = { "Deltifying" => [], "Writing" => [] }
    @push.process_push(@process_io,
      :start => lambda { |state, count| started_count[state] = count },
      :progress => lambda { |state, percent, index, count| output[state] << [percent, index, count] },
      :end => lambda { |state, count| finished[state] = true }
    )

    ["Deltifying", "Writing"].each do |state|
      assert_equal 6, started_count[state]
      assert_equal [0, 16, 33, 50, 66, 83, 100], output[state].map { |o| o[0] }
      assert_equal (0..6).to_a, output[state].map { |o| o[1] }
      assert_equal [6] * 7, output[state].map { |o| o[2] }
      assert_equal true, finished[state]
    end
  end

  def test_should_return_a_list_of_all_revisions_pushed
    output = @push.process_push(@process_io)
    expected = {
      "refs/heads/satellite" => ["60a254470cd97af3668ed4d6405633af850139c6", "746fba2424e6b94570fc395c472805625ab2ed25"],
      "refs/heads/mybranch" => ["f0f27c95b7cdf4ca3b56ecb3c54ef3364133eb6a", "d8b368361ebdf2c51b78f7cfdae5c3044b23d189"]
    }
    assert_equal expected, output[:pushes]
  end

  def test_should_return_nothing_to_push_if_everything_up_to_date
    output = @push.process_push(StringIO.new("Everything up-to-date\n"))
    assert_equal true, output[:nothing_to_push]
  end
end

class TestPushFrom1543 < Test::Unit::TestCase
  include TestHelpers

  def setup
    @push = Git.new
    @push.version = "1.5.4.3"
    @process_io = StringIO.new(fixture_file("push_1_5_4_3_output.txt"))
  end

  def test_should_call_progress_proc_for_compressing
    output = { "Compressing" => [], "Writing" => [] }
    @push.process_push(@process_io,
      :progress => lambda { |state, percent, index, count| output[state] << [percent, index, count] }
    )
    assert_equal [50, 100], output["Compressing"].map { |o| o[0] }
    assert_equal [1, 2], output["Compressing"].map { |o| o[1] }
    assert_equal [2, 2], output["Compressing"].map { |o| o[2] }
    assert_equal [33, 66, 100], output["Writing"].map { |o| o[0] }
    assert_equal [1, 2, 3], output["Writing"].map { |o| o[1] }
    assert_equal [3, 3, 3], output["Writing"].map { |o| o[2] }
  end

  def test_should_extract_push_information
    output = @push.process_push(@process_io)
    assert_equal ["865f920", "f9ca10d"], output[:pushes]['asdf']
    assert_nil output[:pushes]['master']
  end
end
