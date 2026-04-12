require File.dirname(__FILE__) + '/../../test_helper'

class TestRemote < Test::Unit::TestCase
  include TestHelpers

  def setup
    @git = Git.new
    Git.reset_mock!
  end

  def test_should_return_a_list_of_remote_names
    Git.command_response["remote"] = "github\norigin"
    assert_equal ["github", "origin"], @git.remote.names
  end

  def test_should_return_an_array_of_remote_proxy_objects
    Git.command_response["remote"] = "origin"
    remotes = @git.remote.all
    assert_equal 1, remotes.length
    assert_kind_of Git::Remote::RemoteProxy, remotes.first
    assert_equal "origin", remotes.first.name
  end

  def test_should_retrieve_a_fetch_refspec
    refspec = "+refs/heads/*:refs/remotes/origin/*"
    @git.config.define_singleton_method(:[]) do |*args|
      if args == ["remote.origin.fetch"]
        refspec
      else
        super(*args)
      end
    end
    assert_equal refspec, @git.remote["origin"].fetch_refspec
  end

  def test_should_find_the_local_name_for_a_refspec
    remote = @git.remote["origin"]
    remote.define_singleton_method(:fetch_refspec) { |*_| "+refs/heads/*:refs/remotes/origin/*" }
    assert_equal "origin/master", remote.remote_branch_name_for("refs/heads/master")
    assert_equal "origin/master", remote.remote_branch_name_for("master")
    assert_equal "refs/remotes/origin/master", remote.remote_branch_name_for("refs/heads/master", :full)
  end

  def test_should_find_the_remote_refspec_prefix
    remote = @git.remote["origin"]
    remote.define_singleton_method(:fetch_refspec) { |*_| "+refs/heads/*:refs/remotes/origin/*" }
    assert_equal "refs/remotes/origin/", remote.remote_branch_prefix
  end
end
