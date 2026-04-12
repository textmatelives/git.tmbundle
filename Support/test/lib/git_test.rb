require File.dirname(__FILE__) + '/../test_helper'

class TestGit < Test::Unit::TestCase
  include TestHelpers

  def setup
    @git = SCM::Git.new
    Git.reset_mock!
  end

  def test_should_describe_a_revision_defaulting_to_use_all_refs
    Git.command_response["describe", "--all", "1234"] = "tag-1234\n"
    `ls` # set the exit status code to 0
    assert_equal "tag-1234", @git.describe("1234")
  end

  def test_should_return_the_current_revision
    Git.command_response["rev-parse", "HEAD"] = "1234\n"
    assert_equal "1234", @git.current_revision
  end

  def test_should_auto_add_rm_files_depending_on_their_existence
    # Override File.exist? for our specific test paths, then override
    # add/rm on the git instance to track calls instead of running commands.
    add_called_with = nil
    rm_called_with = nil

    original_exist = File.method(:exist?)
    File.define_singleton_method(:exist?) do |path|
      case path
      when "/base/existing_file.txt" then true
      when "/base/deleted_file.txt" then false
      else original_exist.call(path)
      end
    end

    @git.define_singleton_method(:add) { |files| add_called_with = files; "" }
    @git.define_singleton_method(:rm) { |files| rm_called_with = files; "" }

    @git.auto_add_rm(["existing_file.txt", "deleted_file.txt"])

    assert_equal ["existing_file.txt"], add_called_with
    assert_equal ["deleted_file.txt"], rm_called_with
  ensure
    # Restore File.exist?
    File.define_singleton_method(:exist?) { |path| original_exist.call(path) }
  end

  def test_submodule_should_return_absolute_paths
    sub_git = Git.new(:parent => @git, :path => File.join(@git.path, "subproject"))
    assert_equal File.join(@git.path, "subproject/file.txt"), sub_git.path_for("file.txt")
  end

  def test_submodule_should_return_a_relative_path_from_the_root_git
    sub_git = Git.new(:parent => @git, :path => File.join(@git.path, "subproject"))
    assert_equal "subproject/file.txt", sub_git.root_relative_path_for("file.txt")
  end
end
