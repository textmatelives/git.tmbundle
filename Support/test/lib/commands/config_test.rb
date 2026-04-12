require File.dirname(__FILE__) + '/../../test_helper'

class TestConfig < Test::Unit::TestCase
  include TestHelpers

  def setup
    @git = SCM::Git.new
    Git.reset_mock!
  end

  def test_should_let_git_decide_when_scope_not_specified
    Git.command_response["config", "remote.origin.url"] = "../origin"
    value = @git.config["remote.origin.url"]
    assert_equal ["config", "remote.origin.url"], Git.commands_ran.first
    assert_equal "../origin", value
  end

  def test_should_default_to_local_when_writing
    Git.command_response["config", "remote.origin.url", "../origin"] = ""
    @git.config["remote.origin.url"] = "../origin"
    assert_equal ["config", "remote.origin.url", "../origin"], Git.commands_ran.first
  end

  def test_should_allow_reading_of_local_values
    Git.command_response["config", "--file", "/base/.git/config", "remote.origin.url"] = "../origin"
    value = @git.config[:local, "remote.origin.url"]
    assert_equal ["config", "--file", "/base/.git/config", "remote.origin.url"], Git.commands_ran.first
    assert_equal "../origin", value
  end

  def test_should_allow_writing_of_local_values
    Git.command_response["config", "--file", "/base/.git/config", "remote.origin.url", "../origin"] = ""
    @git.config[:local, "remote.origin.url"] = "../origin"
    assert_equal ["config", "--file", "/base/.git/config", "remote.origin.url", "../origin"], Git.commands_ran.first
  end

  def test_should_delete_local_values_when_assigning_nil
    @git.config[:local, "git-tmbundle.log.limit"] = nil
    assert_equal ["config", "--file", "/base/.git/config", "--unset", "git-tmbundle.log.limit"], Git.commands_ran.first
  end

  def test_should_allow_reading_global_values
    Git.command_response["config", "--global", "remote.origin.url"] = "../origin"
    value = @git.config[:global, "remote.origin.url"]
    assert_equal ["config", "--global", "remote.origin.url"], Git.commands_ran.first
    assert_equal "../origin", value
  end

  def test_should_raise_when_given_unknown_scope
    assert_raises(RuntimeError) { @git.config[:boogy, "remote.origin.url"] }
  end

  def test_should_respond_to_string_version_of_global_as_well_as_symbol
    Git.command_response["config", "--global", "remote.origin.url"] = "../origin"
    assert_equal "../origin", @git.config[:global, "remote.origin.url"]
    assert_equal "../origin", @git.config["global", "remote.origin.url"]
  end

  def test_should_allow_writing_global_values
    Git.command_response["config", "--global", "remote.origin.url", "../origin"] = ""
    @git.config[:global, "remote.origin.url"] = "../origin"
    assert_equal ["config", "--global", "remote.origin.url", "../origin"], Git.commands_ran.first
  end

  def test_should_return_nil_on_blank_nonexisting_value
    Git.command_output << ""
    assert_nil @git.config["remote.origin.url"]
  end
end
