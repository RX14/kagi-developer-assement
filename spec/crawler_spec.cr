require "./spec_helper"

describe SearchEngine::Crawler do
  it "parses pages" do
    page = SearchEngine::Crawler.new.crawl(spec_url("sample1.html"))
    title = page.html.xpath_node("//head/title").not_nil!.content
    title.should eq("Text Summarization | Text Summarization Using Deep Learning")
  end

  it "raises on non-200 error code" do
    expect_raises(SearchEngine::Crawler::Error, "returned status INTERNAL_SERVER_ERROR") do
      SearchEngine::Crawler.new.crawl(spec_url("status/500"))
    end
  end

  it "handles redirects" do
    page = SearchEngine::Crawler.new.crawl(spec_url("redirect"))
    title = page.html.xpath_node("//head/title").not_nil!.content
    title.should eq("Text Summarization | Text Summarization Using Deep Learning")
  end

  it "caches pages" do
    crawler = SearchEngine::Crawler.new

    page = crawler.crawl(spec_url("random"))
    content1 = page.html.xpath_node("//body").not_nil!.content

    page = crawler.crawl(spec_url("random"))
    content2 = page.html.xpath_node("//body").not_nil!.content

    content1.should eq(content2)

    crawler.clear_cache

    page = crawler.crawl(spec_url("random"))
    content3 = page.html.xpath_node("//body").not_nil!.content

    page = crawler.crawl(spec_url("random"))
    content4 = page.html.xpath_node("//body").not_nil!.content

    content3.should eq(content4)
    content3.should_not eq(content1)
  end
end
