require "./search_engine"
require "kemal"
require "json"

private class Command
  include JSON::Serializable

  # Type of command, either "crawl" or "clear_cache".
  getter type : String

  # Array of URLs to crawl. Present iff `type` is "crawl".
  getter urls : Array(String)?
end

private class Response
  include JSON::Serializable

  # Type of response, either "result" or "done".
  #
  # In response to a "crawl" command, a "result" response is returned once for
  # each URL, followed by a "done" to indicate the crawl is complete.
  getter type : String

  # Crawl result, present iff `type` is "result".
  getter crawl_result : SearchEngine::Result?

  # Total time to handle the crawl command, present iff `type` is "done".
  getter total_time : Float64?

  def initialize(*, @crawl_result : SearchEngine::Result)
    @type = "result"
  end

  def initialize(*, total_time : Time::Span)
    @type = "done"
    @total_time = total_time.to_f
  end
end

ENGINE = SearchEngine.new

private def crawl(ws, command)
  time = Time.measure do
    urls = command.urls.not_nil!.map { |url| URI.parse(url) }
    result_chan = ENGINE.crawl(urls)

    while result = result_chan.receive?
      ws.send(Response.new(crawl_result: result).to_json)
    end
  end

  ws.send(Response.new(total_time: time).to_json)
end

get "/" do |env|
  env.redirect("/index.html")
end

ws "/websocket" do |ws|
  ws.on_message do |message|
    begin
      command = Command.from_json(message)
    rescue ex : JSON::ParseException
      next ws.close(:unsupported_data, "Invalid JSON")
    end

    case command.type
    when "crawl"
      crawl(ws, command)
    when "clear_cache"
      ENGINE.crawler.clear_cache
    else
      next ws.close(:unsupported_data, "Invalid command type")
    end
  rescue ex
    ws.close(:internal_server_error, ex.inspect_with_backtrace)
  end
end
