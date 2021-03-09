require "spec"
require "http"
require "../src/search_engine"
require "../src/web_server"

SPEC_SERVER = begin
  # Run a HTTP server for specs to access
  server = HTTP::Server.new([
    HTTP::StaticFileHandler.new(__DIR__ + "/data", directory_listing: false),
  ]) do |ctx|
    case ctx.request.path
    when "/status/500"
      ctx.response.respond_with_status(500)
    when "/redirect"
      ctx.response.headers["Location"] = "/sample1.html"
      ctx.response.status_code = 302
    when "/random"
      ctx.response.puts Random::DEFAULT.hex(8)
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

def empty_html
  XML.parse_html("<html></html>")
end

def page(uri, html)
  uri = URI.parse(uri) unless uri.is_a?(URI)
  html = XML.parse_html(html) unless html.is_a?(XML::Node)
  SearchEngine::Crawler::Page.new(uri, html)
end

def crawl(route)
  SearchEngine::Crawler.new.crawl(spec_url(route))
end
