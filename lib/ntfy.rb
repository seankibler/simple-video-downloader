require "net/http"
require "uri"

class Ntfy
    def initialize(topic, server = nil)
        @topic = topic
        @server = server || "https://ntfy.sh"
    end

    def send_notification(title, message)
        uri = URI("#{@server}/#{@topic}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.read_timeout = 5
        http.open_timeout = 5

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Title"] = title
        request["Priority"] = "default"
        request.body = message

        http.request(request)
    rescue => e
        Rails.logger.error "Failed to send notification: #{e.message}"
        false
    ensure
        http.finish if http.present? && http.started?
    end
end
