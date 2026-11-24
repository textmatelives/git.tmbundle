require 'test/unit'
require 'cgi'
require File.expand_path('../../../lib/link_urls', __FILE__)

# LinkURLs works on text that has already been HTML-escaped, the way the
# push output is before it goes into a <pre>.
class TestLinkURLs < Test::Unit::TestCase
  PUSH_OUTPUT = <<-EOF
remote:
remote: Create a pull request for 'feature/x' on GitHub by visiting:
remote:      https://github.com/textmatelives/git.tmbundle/pull/new/feature/x
remote:
To github.com:textmatelives/git.tmbundle.git
 * [new branch]      feature/x -> feature/x
  EOF

  def linkify(text)
    LinkURLs.linkify(CGI.escapeHTML(text))
  end

  def test_links_the_pull_request_url_git_prints_after_a_push
    html = linkify(PUSH_OUTPUT)
    assert_match %r{<a href="https://github.com/textmatelives/git.tmbundle/pull/new/feature/x">https://github.com/textmatelives/git.tmbundle/pull/new/feature/x</a>}, html
    assert_equal 1, html.scan('<a ').length
  end

  def test_keeps_the_rest_of_the_text_escaped
    html = linkify(PUSH_OUTPUT)
    assert_match %r{feature/x -&gt; feature/x}, html
    assert_no_match %r{<a [^>]*>[^<]*-&gt;}, html
  end

  def test_trailing_sentence_punctuation_stays_outside_the_link
    assert_equal %(see <a href="https://example.com/a">https://example.com/a</a>.), linkify("see https://example.com/a.")
    assert_equal %((<a href="https://example.com/a">https://example.com/a</a>)), linkify("(https://example.com/a)")
    assert_equal %(<a href="https://example.com/a_(b)">https://example.com/a_(b)</a>), linkify("https://example.com/a_(b)")
  end

  def test_query_strings_survive_escaping
    assert_equal %(<a href="https://example.com/?a=1&amp;b=2">https://example.com/?a=1&amp;b=2</a>), linkify("https://example.com/?a=1&b=2")
  end

  def test_text_without_urls_is_untouched
    assert_equal "Everything up-to-date\n", linkify("Everything up-to-date\n")
  end
end
