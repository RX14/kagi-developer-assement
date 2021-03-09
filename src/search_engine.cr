require "redis"

# `SearchEngine` implements the logic to crawl and extract dates from a list of
# URLs in parallel.
class SearchEngine
  VERSION = "0.1.0"

  getter crawler : Crawler

  def initialize(redis_host = "localhost", redis_port = 6379)
    @crawler = Crawler.new(redis_host, redis_port)
  end

  # Crawls a list of URLs in parallel, returning a channel of `Result`s.
  # The channel will be closed once the final result is sent.
  def crawl(urls : Array(URI)) : Channel(Result)
    channel = Channel(Result).new(10)
    atomic = Atomic.new(urls.size)

    urls.each do |url|
      spawn do
        date = nil
        error_message = nil

        crawl_time = Time.measure do
          page = @crawler.crawl(url)
          date = DateExtraction.extract_date(page)
        rescue ex
          error_message = ex.message
        end

        if error_message
          channel.send Result.new(url, error_message, crawl_time)
        else
          channel.send Result.new(url, date, crawl_time)
        end

        if atomic.sub(1) == 1
          # We are the final fiber to complete, close the channel
          # We test against 1 because #sub returns the old value of the atomic.
          channel.close
        end
      end
    end

    channel
  end

  # A result for the search engine for a single URL.
  # Contains date extracted, as well as crawl time.
  class Result
    getter url : URI
    getter date : DateExtraction::Date?
    getter error_message : String?
    getter crawl_time : Time::Span

    def initialize(@url, @date : DateExtraction::Date?, @crawl_time)
    end

    def initialize(@url, @error_message : String, @crawl_time)
    end

    # Serializes this result to JSON.
    #
    # The `url` is represented in string form, `date`'s representation is
    # documented in `DateExtraction::Date#to_json`, and `crawl_time` is
    # represented as float seconds.
    def to_json(builder)
      {
        url:           url.to_s,
        date:          date,
        error_message: error_message,
        crawl_time:    crawl_time.to_f,
      }.to_json(builder)
    end
  end
end

require "./crawler"
require "./date_extraction"
