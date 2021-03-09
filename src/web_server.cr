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

  def initialize(*, @crawl_result : SearchEngine::Result)
    @type = "result"
  end
end

ENGINE = SearchEngine.new

private def crawl(ws, command)
  begin
    result_chan = ENGINE.crawl(command.urls.map { |url| URI.parse(url) })
  rescue ex : URI::Error
    return ws.close(:unsupported_data, "Invalid URI")
  end

  while result = result_chan.receive?
    ws.send(Response.new(crawl_result: result).to_json)
  end
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
