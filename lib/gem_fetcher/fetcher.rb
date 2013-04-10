require 'net/http'
require 'net/http/persistent'
require 'time'

module GemFetcher
  class Fetcher

    class Error < StandardError; end

    def initialize
      @http = Net::HTTP::Persistent.new(self.class.name, :ENV)
    end

    # Fetch a source path under the base uri and return the response
    # body. For our purposes, streaming the response to disk doesn't
    # make sense because we want to subsequently read the gemspec out of
    # the gems we fetch (and we're writing the gem to potentially slow
    # storage when we're done).
    def fetch(uri)
      tries ||= 0
      req = Net::HTTP::Get.new URI.parse(uri).path

      @http.request(URI(uri), req) do |resp|
        return handle_response(resp)
      end
    rescue Errno::ETIMEDOUT
      raise if tries > 5
      sleep(1 << tries)
      tries += 1
      retry
    end

    # Handle an http response, follow redirects, etc. returns true if a file was
    # downloaded, false if a 304. Raise Error on unknown responses.
    def handle_response(response)
      case response.code.to_i
      when 302
        fetch(response['location'])
      when 404
        nil
      when 200
        response.body
      else
        raise Error, "unexpected response #{response.inspect}"
      end
      # TODO rescue http errors and reraise cleanly
    end


  end
end

