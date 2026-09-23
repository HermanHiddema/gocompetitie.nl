require "test_helper"

class Egd::ClientTest < ActiveSupport::TestCase
  # Collects the requests the client makes and answers them with prepared
  # responses, so the tests never reach the European Go Database itself.
  class FakeHttp
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def request(request)
      @requests << request
      @responses.shift
    end
  end

  test "a token is required" do
    assert_raises(Egd::Error) { Egd::Client.new(token: nil) }
    assert_raises(Egd::Error) { Egd::Client.new(token: "") }
  end

  test "players are read page by page" do
    http = FakeHttp.new([
      success(players: [{ "pin" => 1 }], has_more_pages: true),
      success(players: [{ "pin" => 2 }], has_more_pages: false)
    ])

    players = with_http(http) do
      Egd::Client.new(token: "secret").players(filter: { countryCode: "NL" }, limit: 2).to_a
    end

    assert_equal [1, 2], players.map { |player| player["pin"] }
    assert_equal 2, http.requests.size

    request = http.requests.first
    assert_equal "Bearer secret", request["Authorization"]
    body = JSON.parse(request.body)
    assert_equal "NL", body.dig("variables", "countryCode")
    assert_equal 1, body.dig("variables", "page")
    assert_equal 2, body.dig("variables", "limit")
    assert_equal 2, JSON.parse(http.requests.last.body).dig("variables", "page")
    assert_not_includes body.dig("query"), "$pagination"
    assert_not_includes body.dig("query"), "$filter"
  end

  test "players can be searched by text" do
    http = FakeHttp.new([
      search_success(players: [{ "pin" => 1, "firstName" => "Jan" }], has_more_pages: false)
    ])

    players = with_http(http) do
      Egd::Client.new(token: "secret").search_players("Jan", limit: 5).to_a
    end

    assert_equal [1], players.map { |player| player["pin"] }

    body = JSON.parse(http.requests.first.body)
    assert_equal "Jan", body.dig("variables", "search")
    assert_nil body.dig("variables", "filter")
    assert_equal 1, body.dig("variables", "page")
    assert_equal 5, body.dig("variables", "limit")
    assert_not_includes body.dig("query"), "$pagination"
  end

  test "searching players does not page past the requested limit" do
    http = FakeHttp.new([
      search_success(players: [{ "pin" => 1 }], has_more_pages: true),
      search_success(players: [{ "pin" => 2 }], has_more_pages: false)
    ])

    players = with_http(http) do
      Egd::Client.new(token: "secret").search_players("Jan", limit: 20).to_a
    end

    assert_equal [1], players.map { |player| player["pin"] }
    assert_equal 1, http.requests.size
    assert_equal 1, JSON.parse(http.requests.first.body).dig("variables", "page")
    assert_equal 20, JSON.parse(http.requests.first.body).dig("variables", "limit")
  end

  test "the page size stays within the maximum of the API" do
    http = FakeHttp.new([success(players: [], has_more_pages: false)])

    with_http(http) { Egd::Client.new(token: "secret").players(limit: 500).to_a }

    assert_equal 100, JSON.parse(http.requests.first.body).dig("variables", "limit")
  end

  test "GraphQL errors are reported" do
    http = FakeHttp.new([response(Net::HTTPOK, "200", { errors: [{ message: "Kapot" }] }.to_json)])

    error = assert_raises(Egd::Error) do
      with_http(http) { Egd::Client.new(token: "secret").players.to_a }
    end

    assert_includes error.message, "Kapot"
  end

  test "a rejected token is reported" do
    http = FakeHttp.new([response(Net::HTTPUnauthorized, "401", "")])

    error = assert_raises(Egd::Error) do
      with_http(http) { Egd::Client.new(token: "secret").players.to_a }
    end

    assert_includes error.message, "401"
  end

  test "other HTTP errors are reported" do
    http = FakeHttp.new([response(Net::HTTPServiceUnavailable, "503", "")])

    error = assert_raises(Egd::Error) do
      with_http(http) { Egd::Client.new(token: "secret").players.to_a }
    end

    assert_includes error.message, "503"
  end

  test "socket errors are reported" do
    error = assert_raises(Egd::Error) do
      with_http_start(->(*, **, &) { raise SocketError, "getaddrinfo: Name or service not known" }) do
        Egd::Client.new(token: "secret").players.to_a
      end
    end

    assert_includes error.message, "niet bereikbaar"
  end

  private
    def with_http(http, &block)
      with_http_start(->(*, **, &connection) { connection.call(http) }, &block)
    end

    def with_http_start(start, &block)
      singleton_class = Net::HTTP.singleton_class
      original_start = Net::HTTP.method(:start)
      singleton_class.send(:define_method, :start, start)
      block.call
    ensure
      singleton_class.send(:define_method, :start, original_start)
    end

    def success(players:, has_more_pages:)
      body = { data: { players: { data: players, hasMorePages: has_more_pages } } }.to_json
      response(Net::HTTPOK, "200", body)
    end

    def search_success(players:, has_more_pages:)
      body = { data: { playersSearch: { data: players, hasMorePages: has_more_pages } } }.to_json
      response(Net::HTTPOK, "200", body)
    end

    def response(type, code, body)
      response = type.new("1.1", code, "")
      response.instance_variable_set(:@body, body)
      response.instance_variable_set(:@read, true)
      response
    end
end
