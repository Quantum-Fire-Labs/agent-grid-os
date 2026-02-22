require "net/http"
require "uri"
require "cgi"

class WebSearch
  USER_AGENT = "AgentGridOS/1.0"

  def initialize(agent:)
    @agent = agent
  end

  def call(name, arguments)
    query = arguments["query"].to_s.strip
    return "Error: query is required" if query.empty?

    url = "https://html.duckduckgo.com/html/?" + URI.encode_www_form(q: query)
    uri = URI.parse(url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT

    response = http.request(request)
    return "Search error: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    body = response.body.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    parse_results(body)
  rescue StandardError => e
    "Search error: #{e.message}"
  end

  private

  def parse_results(html)
    results = []

    html.scan(/<a[^>]+class="result__a"[^>]+href="([^"]*)"[^>]*>(.*?)<\/a>/mi) do |href, title_html|
      title = strip_tags(title_html).strip
      actual_url = extract_url(href)
      results << { title: title, url: actual_url }
    end

    snippets = html.scan(/<a[^>]+class="result__snippet"[^>]*>(.*?)<\/a>/mi).map { |m| strip_tags(m[0]).strip }

    output = results.first(8).each_with_index.map do |r, i|
      snippet = snippets[i] || ""
      "#{i + 1}. #{r[:title]}\n   #{r[:url]}\n   #{snippet}"
    end

    output.any? ? output.join("\n\n") : "No results found."
  end

  def extract_url(href)
    if href.include?("uddg=")
      match = href.match(/uddg=([^&]+)/)
      match ? CGI.unescape(match[1]) : href
    else
      href
    end
  end

  def strip_tags(html)
    html
      .gsub(/<[^>]+>/, "")
      .gsub(/&nbsp;/, " ")
      .gsub(/&amp;/, "&")
      .gsub(/&lt;/, "<")
      .gsub(/&gt;/, ">")
      .gsub(/&quot;/, '"')
      .gsub(/&#\d+;/, "")
      .gsub(/\s+/, " ")
      .strip
  end
end
