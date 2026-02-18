require "net/http"
require "resolv"
require "ipaddr"

class Agent::Tools::WebFetch < Agent::Tools::Base
  MAX_CHARS = 12_000
  MAX_REDIRECTS = 3
  USER_AGENT = "AgentGridOS/1.0"

  BLOCKED_NETWORKS = [
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("169.254.0.0/16"),
    IPAddr.new("0.0.0.0/8"),
    IPAddr.new("::1/128"),
    IPAddr.new("fd00::/8")
  ].freeze

  BLOCKED_HOSTNAMES = %w[localhost].freeze

  def self.definition
    {
      type: "function",
      function: {
        name: "web_fetch",
        description: "Fetch a URL and return its content as plain text. Useful for reading web pages, APIs, or any HTTP resource.",
        parameters: {
          type: "object",
          properties: {
            url: { type: "string", description: "The URL to fetch" }
          },
          required: [ "url" ]
        }
      }
    }
  end

  def call
    url = arguments["url"]
    return "Error: url is required" if url.blank?

    fetch(url)
  rescue StandardError => e
    "Fetch error: #{e.message}"
  end

  private

    def fetch(url, redirects = 0)
      uri = URI.parse(url)
      return "Error: invalid URL" unless uri.is_a?(URI::HTTP)

      error = validate_host(uri.host)
      return error if error

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 20

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT

      response = http.request(request)

      case response
      when Net::HTTPRedirection
        return "Error: too many redirects" if redirects >= MAX_REDIRECTS
        fetch(response["location"], redirects + 1)
      when Net::HTTPSuccess
        extract_text(response)
      else
        "HTTP #{response.code}: #{response.message}"
      end
    end

    def validate_host(hostname)
      return "Error: requests to #{hostname} are not allowed" if BLOCKED_HOSTNAMES.include?(hostname.downcase)

      addresses = Resolv.getaddresses(hostname)
      return "Error: could not resolve hostname #{hostname}" if addresses.empty?

      addresses.each do |addr|
        ip = IPAddr.new(addr)
        if BLOCKED_NETWORKS.any? { |net| net.include?(ip) }
          return "Error: requests to private/internal addresses are not allowed"
        end
      end

      nil
    rescue IPAddr::InvalidAddressError
      "Error: invalid address for #{hostname}"
    end

    def extract_text(response)
      body = response.body.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      content_type = response["Content-Type"].to_s

      text = if content_type.include?("html") || body.lstrip.start_with?("<!", "<html")
        strip_html(body)
      else
        body
      end

      text = text.truncate(MAX_CHARS, omission: "\n\n[Truncated]") if text.length > MAX_CHARS
      text
    end

    def strip_html(html)
      html
        .gsub(/<script[^>]*>.*?<\/script>/mi, "")
        .gsub(/<style[^>]*>.*?<\/style>/mi, "")
        .gsub(/<[^>]+>/, " ")
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
