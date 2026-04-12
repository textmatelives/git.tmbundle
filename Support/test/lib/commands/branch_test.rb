require File.dirname(__FILE__) + '/../../test_helper'

class TestBranch < Test::Unit::TestCase
  include TestHelpers

  def setup
    @git = Git.new
    Git.reset_mock!
    @HEAD_file_path = "#{@git.git_dir}/HEAD"
  end

  def with_head_file(content)
    original_read = File.method(:read)
    File.define_singleton_method(:read) do |path|
      if path == "/base/.git/HEAD"
        content
      else
        original_read.call(path)
      end
    end
    yield
  ensure
    File.define_singleton_method(:read) { |path| original_read.call(path) }
  end

  def test_should_detect_when_not_on_a_branch
    with_head_file("12345678") do
      assert_nil @git.branch.current_name
    end
  end

  def test_should_return_short_version_of_current_branch_by_default
    with_head_file("ref: refs/heads/master") do
      assert_equal "master", @git.branch.current_name
    end
  end

  def test_should_return_long_version_of_current_branch
    with_head_file("ref: refs/heads/master") do
      assert_equal "refs/heads/master", @git.branch.current_name(:long)
    end
  end

  def test_should_return_ahead_when_left_branch_is_ahead
    Git.command_response["rev-list", "--left-right", "master...origin/master"] = <<EOF
<59514d9864d25aa8250aea90f316638529b97801
<09f6c024b03f2143718bc9cf23862963b260378a
EOF
    assert_equal :ahead, @git.branch.compare_status("master", "origin/master")
  end

  def test_should_return_behind_when_left_branch_is_behind
    Git.command_response["rev-list", "--left-right", "origin/master...master"] = <<EOF
>59514d9864d25aa8250aea90f316638529b97801
>09f6c024b03f2143718bc9cf23862963b260378a
EOF
    assert_equal :behind, @git.branch.compare_status("origin/master", "master")
  end

  def test_should_return_diverged_when_branches_have_different_commits
    Git.command_response["rev-list", "--left-right", "master...origin/master"] = <<EOF
<59514d9864d25aa8250aea90f316638529b97801
>09f6c024b03f2143718bc9cf23862963b260378a
EOF
    assert_equal :diverged, @git.branch.compare_status("master", "origin/master")
  end
end

class TestBranchListing < Test::Unit::TestCase
  include TestHelpers

  def setup
    @git = Git.new
    Git.reset_mock!
    @HEAD_file_path = "#{@git.git_dir}/HEAD"

    Git.command_response["for-each-ref", "refs/heads"] = <<EOF
7dd2ef4bbb97536b1c4a014d87eafbb4b41030e8 commit\trefs/heads/test_mod
59514d9864d25aa8250aea90f316638529b97801 commit\trefs/heads/master
EOF
    Git.command_response["for-each-ref", "refs/remotes"] = <<EOF
7dd2ef4bbb97536b1c4a014d87eafbb4b41030e8 commit\trefs/remotes/origin/alpha
59514d9864d25aa8250aea90f316638529b97801 commit\trefs/remotes/origin/test_mod
59514d9864d25aa8250aea90f316638529b97801 commit\trefs/remotes/origin/master
EOF
  end

  def with_head_file(content)
    original_read = File.method(:read)
    File.define_singleton_method(:read) do |path|
      if path == "/base/.git/HEAD"
        content
      else
        original_read.call(path)
      end
    end
    yield
  ensure
    File.define_singleton_method(:read) { |path| original_read.call(path) }
  end

  def test_should_return_a_list_of_branches
    assert_equal 5, @git.branch.all.length
  end

  def test_should_filter_to_remote_branches
    assert_equal 3, @git.branch.all(:remote).length
  end

  def test_should_filter_to_local_branches
    assert_equal 2, @git.branch.all(:local).length
  end

  def test_should_shorten_branch_names_by_default
    assert_equal "test_mod", @git.branch.all(:local).first.name
    assert_equal "origin/alpha", @git.branch.all(:remote).first.name
  end

  def test_should_filter_to_a_remote
    # Stub the remote objects to provide remote_branch_prefix
    origin_remote = @git.remote["origin"]
    origin_remote.define_singleton_method(:remote_branch_prefix) { "refs/remotes/origin/" }
    gitorious_remote = @git.remote["gitorious"]
    gitorious_remote.define_singleton_method(:remote_branch_prefix) { "refs/remotes/gitorious/" }

    assert_equal 3, @git.branch.all(:remote, :remote => "origin").length
    assert_equal 0, @git.branch.all(:remote, :remote => "gitorious").length
  end

  def test_should_discern_remote_and_local
    assert @git.branch.all(:local).first.local?
    assert @git.branch.all(:remote).first.remote?
  end

  def test_should_know_if_current_branch_or_not
    branch = @git.branch.all(:local).first
    with_head_file("ref: #{branch.name(:full)}") do
      assert branch.current?
    end
    with_head_file("1234") do
      refute branch.current?
    end
  end

  def test_should_return_the_current_branch
    with_head_file("ref: refs/heads/master") do
      assert_equal "master", @git.branch.current.name
    end
  end
end

class TestBranchQuery < Test::Unit::TestCase
  include TestHelpers

  def setup
    @git = Git.new
    Git.reset_mock!
    @branch = Git::Branch::BranchProxy.new(
      @git, @git.branch,
      :name => "refs/heads/master",
      :ref => "59514d9864d25aa8250aea90f316638529b97801"
    )
  end

  def test_should_get_the_remote_name_for_a_branch
    @git.config.define_singleton_method(:[]) do |*args|
      if args == ["branch.master.remote"]
        "origin"
      else
        super(*args)
      end
    end
    assert_equal "origin", @branch.remote.name
  end

  def test_should_get_the_tracking_branch
    @git.config.define_singleton_method(:[]) do |*args|
      case args
      when ["branch.master.remote"] then "origin"
      when ["branch.master.merge"] then "refs/heads/master"
      when ["remote.origin.fetch"] then "+refs/heads/*:refs/remotes/origin/*"
      else super(*args)
      end
    end
    # Need to stub remote_branch_name_for on the remote proxy
    remote_proxy = @git.remote["origin"]
    remote_proxy.define_singleton_method(:remote_branch_name_for) do |branch_name, format = :short|
      if branch_name == "refs/heads/master" && format == :long
        "refs/remotes/origin/master"
      elsif branch_name == "refs/heads/master"
        "origin/master"
      end
    end
    assert_equal "origin/master", @branch.tracking_branch_name
  end

  def test_should_report_tracking_status_as_nil_when_no_tracking
    @git.config.define_singleton_method(:[]) do |*args|
      if args == ["branch.master.remote"]
        nil
      else
        super(*args)
      end
    end
    assert_nil @branch.tracking_status
  end

  def test_should_report_the_tracking_status
    @branch.define_singleton_method(:tracking_branch_name) do |format = :short|
      format == :long ? "refs/remotes/origin/master" : "origin/master"
    end
    @git.branch.define_singleton_method(:compare_status) do |left, right|
      if left == "refs/heads/master" && right == "refs/remotes/origin/master"
        :ahead
      end
    end
    assert_equal :ahead, @branch.tracking_status
  end
end
