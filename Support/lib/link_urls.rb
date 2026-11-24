# Turns the URLs in a block of already HTML-escaped text into links, so that
# a URL git prints (for example GitHub's "Create a pull request … by
# visiting:" line after a push) can be clicked in the output window, which
# opens http(s) links in the default browser.
module LinkURLs
  # Characters a URL is allowed to run over; the text is HTML-escaped, so
  # `&amp;` and `&#39;` are legitimate parts of a link.
  URL = %r{https?://[^\s<>"]+}

  # Punctuation that belongs to the sentence, not to the URL.
  TRAILING = /[.,;:!?]+\z/

  module_function

  def linkify(escaped_html)
    escaped_html.gsub(URL) do |match|
      url = match.sub(TRAILING, "")
      url = url.chomp(")") if url.count("(") < url.count(")")
      rest = match[url.length..-1]
      %(<a href="#{url}">#{url}</a>#{rest})
    end
  end
end
