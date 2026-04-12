require File.dirname(__FILE__) + '/../../test_helper'

class TestSubmoduleListing < Test::Unit::TestCase
  include TestHelpers

  def setup
    @git = Git.new
    Git.reset_mock!
  end

  def test_should_return_all_submodules
    Git.command_response["ls-files", "--stage"] = <<EOF
160000 03a20cfe2e0e344f87ac3132ddc991899cef2567 0\tvendor/plugins/fixture-scenarios
160000 e741e43171fd34c98ef98afa5877fb2d74841b82 0\tvendor/plugins/mod
160000 b9276ab1ad9aee7c3688b365072fe0a616b68b71 0\tvendor/plugins/railswhere
EOF
    submodules = @git.submodule.all
    assert_equal 3, submodules.length

    assert_equal "03a20cfe2e0e344f87ac3132ddc991899cef2567", submodules[0].revision
    assert_equal "vendor/plugins/fixture-scenarios", submodules[0].path
    assert_nil submodules[0].tag

    assert_equal "e741e43171fd34c98ef98afa5877fb2d74841b82", submodules[1].revision
    assert_equal "vendor/plugins/mod", submodules[1].path
    assert_nil submodules[1].tag

    assert_equal "b9276ab1ad9aee7c3688b365072fe0a616b68b71", submodules[2].revision
    assert_equal "vendor/plugins/railswhere", submodules[2].path
    assert_nil submodules[2].tag
  end

  def test_should_list_submodules_in_given_path
    # Override command to verify it receives the right args
    received_args = nil
    @git.define_singleton_method(:command) do |*args|
      received_args = args
      ""
    end
    @git.submodule.all(:path => "path/to/files")
    assert_equal ["ls-files", "--stage", "path/to/files"], received_args
  end

  def test_should_add_a_repository
    repo = "git@server:/repository.git"
    path = "my-path"
    Git.command_response["submodule", "add", "--", repo, path] = ""
    @git.submodule.add(repo, "/base/#{path}")
    assert_equal [["submodule", "add", "--", repo, path]], Git.commands_ran
  end
end

class TestSubmoduleProxy < Test::Unit::TestCase
  include TestHelpers

  def setup
    @git = Git.new
    Git.reset_mock!
    @path = "vendor/plugins/acts_as_plugin"
    @submodule = SCM::Git::Submodule::SubmoduleProxy.new(
      @git, @git.submodule,
      :current_revision => "6789",
      :revision => "1234",
      :path => @path,
      :tag => "release"
    )
    @submodule.define_singleton_method(:url) { "git@url.com/path/to/repo.git" }
  end

  def test_should_cache
    # Track calls to File.exist?, FileUtils.mkdir_p, FileUtils.mv
    file_exist_calls = {}
    original_exist = File.method(:exist?)
    File.define_singleton_method(:exist?) do |p|
      if p == File.join(@submodule_abs_path, "/.git")
        true
      elsif p == @submodule_abs_cache_path
        false
      else
        original_exist.call(p)
      end
    end

    # We need the submodule paths
    abs_path = @submodule.abs_path
    abs_cache_path = @submodule.abs_cache_path

    File.define_singleton_method(:exist?) do |p|
      if p == File.join(abs_path, "/.git")
        true
      elsif p == abs_cache_path
        false
      else
        original_exist.call(p)
      end
    end

    mkdir_p_called_with = nil
    mv_called_with = nil

    FileUtils.define_singleton_method(:mkdir_p) { |p| mkdir_p_called_with = p }
    FileUtils.define_singleton_method(:mv) { |src, dst, opts = {}| mv_called_with = [src, dst, opts] }

    @submodule.cache

    assert_equal File.join(@git.path, ".git/submodule_cache"), File.dirname(abs_cache_path)
    assert_equal abs_path, mv_called_with[0]
    assert_equal abs_cache_path, mv_called_with[1]
    assert_equal({ :force => true }, mv_called_with[2])
  ensure
    File.define_singleton_method(:exist?) { |p| original_exist.call(p) }
    # Restore FileUtils
    FileUtils.singleton_class.send(:remove_method, :mkdir_p) if FileUtils.respond_to?(:mkdir_p)
    FileUtils.singleton_class.send(:remove_method, :mv) if FileUtils.respond_to?(:mv)
  end

  def test_should_restore_when_not_in_working_copy
    abs_path = @submodule.abs_path
    abs_cache_path = @submodule.abs_cache_path

    original_has_a_file = Dir.method(:has_a_file?)
    Dir.define_singleton_method(:has_a_file?) { |p| p == abs_path ? false : original_has_a_file.call(p) }

    original_exist = File.method(:exist?)
    File.define_singleton_method(:exist?) do |p|
      if p == abs_cache_path
        true
      else
        original_exist.call(p)
      end
    end

    mkdir_p_called_with = nil
    mv_called_with = nil
    FileUtils.define_singleton_method(:mkdir_p) { |p| mkdir_p_called_with = p }
    FileUtils.define_singleton_method(:rm_rf) { |p| } # no-op
    FileUtils.define_singleton_method(:mv) { |src, dst, opts = {}| mv_called_with = [src, dst, opts] }

    @submodule.restore

    assert_equal File.dirname(abs_path), mkdir_p_called_with
    assert_equal abs_cache_path, mv_called_with[0]
    assert_equal abs_path, mv_called_with[1]
  ensure
    Dir.define_singleton_method(:has_a_file?) { |p| original_has_a_file.call(p) }
    File.define_singleton_method(:exist?) { |p| original_exist.call(p) }
    FileUtils.singleton_class.send(:remove_method, :mkdir_p) rescue nil
    FileUtils.singleton_class.send(:remove_method, :mv) rescue nil
    FileUtils.singleton_class.send(:remove_method, :rm_rf) rescue nil
  end

  def test_should_return_a_git_object_for_the_submodule
    mock_git = Object.new
    mock_git.define_singleton_method(:current_revision) { "1234" }
    @git.define_singleton_method(:with_path) { |p| mock_git }
    result = @submodule.git
    assert_equal "1234", result.current_revision
  end

  def test_should_query_current_revision_when_asked
    mock_git = Object.new
    mock_git.define_singleton_method(:current_revision) { "1234" }
    @submodule.define_singleton_method(:git) { mock_git }
    assert_equal "1234", @submodule.current_revision(true)
  end

  def test_should_describe_its_revision
    mock_git = Object.new
    mock_git.define_singleton_method(:describe) { |rev| "tag-#{rev}" }
    mock_git.define_singleton_method(:current_revision) { "6789" }
    @submodule.define_singleton_method(:git) { mock_git }
    assert_equal "tag-1234", @submodule.revision_description
  end

  def test_should_describe_its_current_revision
    mock_git = Object.new
    mock_git.define_singleton_method(:describe) { |rev| "tag-#{rev}" }
    mock_git.define_singleton_method(:current_revision) { "6789" }
    @submodule.define_singleton_method(:git) { mock_git }
    assert_equal "tag-6789", @submodule.current_revision_description
  end

  def test_should_be_modified_when_revisions_differ
    @submodule.define_singleton_method(:cloned?) { true }
    assert @submodule.modified?
  end

  def test_should_not_be_modified_when_revisions_are_the_same
    @submodule.define_singleton_method(:cloned?) { true }
    @submodule.define_singleton_method(:current_revision) { |*_| @submodule.revision }
    # Need to make current_revision return @submodule.revision
    rev = @submodule.revision
    @submodule.define_singleton_method(:current_revision) { |*_| rev }
    refute @submodule.modified?
  end

  def test_should_not_be_modified_if_not_checked_out
    @submodule.define_singleton_method(:cloned?) { false }
    refute @submodule.modified?
  end

  def test_should_not_be_cloned_if_git_dir_missing
    abs_path = @submodule.abs_path
    abs_cache_path = @submodule.abs_cache_path
    original_exist = File.method(:exist?)
    File.define_singleton_method(:exist?) do |p|
      if p == File.join(abs_path, ".git")
        false
      elsif p == abs_cache_path
        false
      else
        original_exist.call(p)
      end
    end
    refute @submodule.cloned?
  ensure
    File.define_singleton_method(:exist?) { |p| original_exist.call(p) }
  end

  def test_should_be_cloned_if_git_dir_exists
    abs_path = @submodule.abs_path
    original_exist = File.method(:exist?)
    File.define_singleton_method(:exist?) do |p|
      if p == File.join(abs_path, ".git")
        true
      else
        original_exist.call(p)
      end
    end
    assert @submodule.cloned?
  ensure
    File.define_singleton_method(:exist?) { |p| original_exist.call(p) }
  end

  def test_should_be_cached_if_abs_cache_path_exists
    abs_cache_path = @submodule.abs_cache_path
    original_exist = File.method(:exist?)
    File.define_singleton_method(:exist?) do |p|
      if p == abs_cache_path
        true
      else
        original_exist.call(p)
      end
    end
    assert @submodule.cached?
  ensure
    File.define_singleton_method(:exist?) { |p| original_exist.call(p) }
  end

  def test_should_call_update_on_the_submodule
    @submodule.update
    assert_includes Git.commands_ran, ["submodule", "update", @submodule.path]
  end
end
