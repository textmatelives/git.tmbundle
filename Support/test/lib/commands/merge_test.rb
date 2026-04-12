require File.dirname(__FILE__) + '/../../test_helper'

class TestMergeParsing < Test::Unit::TestCase
  include TestHelpers

  def setup
    @merge = Git.new
  end

  def test_should_extract_conflicts_from_a_merge
    result = @merge.parse_merge(<<-EOF)
Auto-merged project.txt
CONFLICT (content): Merge conflict in project.txt
Auto-merged dude.txt
CONFLICT (add/add): Merge conflict in dude.txt
CONFLICT (delete/modify): lib/file.rb deleted in HEAD and modified in release. Version release of lib/file.rb left in tree.
Auto-merged spec/fixtures/events.yml
CONFLICT (delete/modify): coso.txt deleted in release and modified in HEAD. Version HEAD of coso.txt left in tree.
Automatic merge failed; fix conflicts and then commit the result.
Automatic merge failed; fix conflicts and then commit the result.
EOF
    assert_equal ["project.txt", "dude.txt", "lib/file.rb", "coso.txt"], result[:conflicts]
  end
end
