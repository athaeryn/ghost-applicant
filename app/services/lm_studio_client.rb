class LmStudioError < StandardError; end
class LmStudioUnavailableError < LmStudioError; end

# Thin OpenAI-compatible client for LM Studio's local HTTP server
# (default http://localhost:1234/v1/chat/completions).
class LmStudioClient
  DEFAULT_BASE_URL = "http://localhost:1234"
  CHAT_ENDPOINT = "/v1/chat/completions"
  MODELS_ENDPOINT = "/v1/models"

  attr_reader :base_url, :model

  def initialize(base_url: ENV.fetch("LM_STUDIO_BASE_URL", DEFAULT_BASE_URL), model: nil)
    @base_url = base_url
    @model = model.presence || ENV["LM_STUDIO_MODEL"].presence || default_model
  end

  def chat(messages, temperature: 0.7, max_tokens: 2048)
    response = http_request(build_request(messages, temperature, max_tokens))
    parse(response)
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError, Net::OpenTimeout
    raise LmStudioUnavailableError, "LM Studio is not reachable at #{base_url}. Is the server running?"
  end

  private

  # The running model id, detected from the OpenAI-compatible /v1/models
  # endpoint. Falls back to nil if LM Studio is unreachable.
  def default_model
    @default_model ||= begin
      uri = URI.join("#{base_url.chomp("/")}/", MODELS_ENDPOINT)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      JSON.parse(http_request(request).body).dig("data", 0, "id")
    rescue StandardError
      nil
    end
  end

  def build_request(messages, temperature, max_tokens)
    uri = URI.join("#{base_url.chomp("/")}/", CHAT_ENDPOINT)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    body = { model: model, messages: messages, temperature: temperature, max_tokens: max_tokens }
    body.delete(:model) if model.nil?
    request.body = JSON.generate(body)
    request
  end

  def http_request(request)
    Net::HTTP.new(request.uri.hostname, request.uri.port).tap do |http|
      http.use_ssl = request.uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 120
    end.request(request)
  end

  def parse(response)
    data = JSON.parse(response.body)
    unless response.is_a?(Net::HTTPSuccess)
      raise LmStudioError, "LM Studio error (#{response.code}): #{data["error"] || data.inspect}"
    end

    data.dig("choices", 0, "message", "content")
  end
end
