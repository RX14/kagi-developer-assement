require "http"
require "xml"

# Implements a crawler which takes URLs and fetches the content, returning a
# `Page` object, containing parsed DOM and some metadata.
#
# The crawler uses a redis cache to cache requested pages. They currently do not
# expire.
class SearchEngine::Crawler
  CRAWLER_HEADERS = HTTP::Headers{
    "User-Agent" => "ExampleSearchEngine/#{SearchEngine::VERSION}",
  }

  class Error < Exception
  end

  def initialize(redis_host = "localhost", redis_port = 6379)
    @redis = Redis::PooledClient.new(redis_host, redis_port)
  end

  def crawl(url : URI) : Page
    redis_key = "search_engine:url_cache:#{url}"
    html = @redis.get(redis_key)

    unless html
      html = request(url)
      @redis.set(redis_key, html)
    end

    begin
      html = XML.parse_html(html)
    rescue ex
      raise Crawler::Error.new("parsing HTML", ex)
    end

    Page.new(url, html)
  end

  def request(url : URI) : String
    response = HTTP::Client.get(url, headers: CRAWLER_HEADERS)
    if 300 <= response.status_code < 400 &&
       (location = response.headers["Location"]?)
      return request(url.resolve(location))
    end

    unless response.status.ok?
      raise Crawler::Error.new("URL #{url} returned status #{response.status}")
    end

    response.body
  end

  def clear_cache
    cursor = "0"

    loop do
      cursor, keys = @redis.scan(cursor, "search_engine:url_cache:*")
      @redis.del(keys.as(Array).map(&.as(String)))
      break if cursor == "0"
    end
  end

  class Page
    getter url : URI
    getter html : XML::Node

    def initialize(@url, @html)
    end
  end
end
