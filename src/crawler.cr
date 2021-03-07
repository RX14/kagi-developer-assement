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
      unless response.status.ok?
        raise Crawler::Error.new("URL #{url} returned status #{response.status}")
      end

      xml = XML.parse_html(response.body_io)
      Page.new(xml)
    end
  end

  class Page
    getter dom : XML::Node

    def initialize(@dom)
    end
  end
end
