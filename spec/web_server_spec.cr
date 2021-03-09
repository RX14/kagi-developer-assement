require "./spec_helper"

private class State
  class_property kemal_port : Int32?
end

spawn do
  logging false
  Kemal.run do |config|
    State.kemal_port = config.server.not_nil!.bind_tcp("localhost", 0).port
  end
end

def with_websocket
  ws = HTTP::WebSocket.new("localhost", "/websocket", State.kemal_port)

  ex = nil
  ws.on_close do |code, message|
    next if ws.closed?

    unless code.normal_closure?
      _ex = ex = Exception.new("WebSocket failed #{code} #{message.inspect}")
      _ex.callstack = Exception::CallStack.new
    end
  end

  begin
    yield ws

    ws.run
  ensure
    ws.close
  end

  raise ex.not_nil! if ex
end

describe "SearchEngine web server" do
  describe "/websocket" do
    it "returns crawl data" do
      with_websocket do |ws|
        ws.send %<{"type": "crawl", "urls": [
            #{spec_url("github.html").to_s.to_json},
            #{spec_url("sample1.html").to_s.to_json}
          ]}>

        ws.on_message do |msg|
          json = JSON.parse(msg)

          if json["type"] == "done"
            json["total_time"].as_f
            ws.close
            next
          end

          json["type"].should eq("result")
          case json["crawl_result"]["url"]
          when spec_url("github.html").to_s
            json["crawl_result"]["date"].should eq(nil)
          when spec_url("sample1.html").to_s
            json["crawl_result"]["date"].should eq("Jun 10, 2019")
          else
            raise "BUG"
          end
        end
      end
    end
  end
end
