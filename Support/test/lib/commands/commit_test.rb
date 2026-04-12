require File.dirname(__FILE__) + '/../../test_helper'

class TestCommitParsing < Test::Unit::TestCase
  include TestHelpers

  def setup
    @commit = Git.new
    Git.reset_mock!
  end

  def test_should_parse_a_commit
    Git.command_output << <<-EOF
Created commit ff4ba93: some message
 1 files changed, 2 insertions(+), 0 deletions(-)
Unrecognized line
EOF

    result = @commit.commit("some message")
    assert_equal "ff4ba93", result[:rev]
    assert_equal "some message", result[:message]
    assert_equal 2, result[:insertions]
    assert_equal 0, result[:deletions]
    assert_equal 1, result[:files_changed]
    assert_equal "Unrecognized line\n", result[:output]
  end
end
