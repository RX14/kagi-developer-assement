require "spec"
require "http"
require "../src/search_engine"

SPEC_SERVER = begin
  # Run a HTTP server for specs to access
  server = HTTP::Server.new([
    HTTP::StaticFileHandler.new(__DIR__ + "/data", directory_listing: false),
  ]) do |ctx|
    case ctx.request.path
    when "/status/500"
      ctx.response.respond_with_status(500)
    else
      ctx.response.respond_with_status(404)
    end
  end
  # Let the operating system pick an unused port
  server.bind_tcp("localhost", 0)
  server
end

spawn do
  SPEC_SERVER.listen
  abort("Spec server crashed")
end

def spec_url(route)
  URI.parse("http://#{SPEC_SERVER.addresses.first}/#{route}")
end
