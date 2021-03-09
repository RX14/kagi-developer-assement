require "./search_engine"
require "kemal"
require "json"

class Command
  include JSON::Serializable

  getter type : String

  getter urls : Array(String)
end

class Response
  include JSON::Serializable

  getter type : String

  getter crawl_result : SearchEngine::Result?

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
    result_chan = ENGINE.crawl(command.urls.map { |url| URI.parse(url) })

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
    else
      next ws.close(:unsupported_data, "Invalid command type")
    end
  rescue ex
    ws.close(:internal_server_error, ex.inspect_with_backtrace)
  end
end
