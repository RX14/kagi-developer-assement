require "http"
require "xml"

# Implements a crawler which takes URLs and fetches the content, returning a
# `Page` object, containing parsed DOM and some metadata.
module SearchEngine::Crawler
  CRAWLER_HEADERS = HTTP::Headers{
    "User-Agent" => "ExampleSearchEngine/#{SearchEngine::VERSION}",
  }

  class Error < Exception
  end

  def self.crawl(url : URI) : Page
    # TODO: support redirects
    HTTP::Client.get(url, headers: CRAWLER_HEADERS) do |response|
      if 300 <= response.status_code < 400 &&
         (location = response.headers["Location"]?)
        return crawl(url.resolve(location))
      end

      unless response.status.ok?
        raise Crawler::Error.new("URL #{url} returned status #{response.status}")
      end

      begin
        html = XML.parse_html(response.body_io)
        Page.new(url, html)
      rescue ex
        raise Crawler::Error.new("parsing HTML", ex)
      end
    end
  end

  class Page
    getter url : URI
    getter html : XML::Node

    def initialize(@url, @html)
    end
  end
end
