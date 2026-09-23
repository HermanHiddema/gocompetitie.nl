# Minimal GraphQL client for the European Go Database, see
# docs/egd-graphql-api.md for the API reference.
module Egd
  class Client
    ENDPOINT = "https://europeangodatabase.eu/api/v2026.02/graphql".freeze
    # The API caps the page size of the top level list queries at 100.
    MAX_PAGE_SIZE = 100
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30

    PLAYERS_QUERY = <<~GRAPHQL.freeze
      query Players(
        $pin: Int, $countryCode: String, $grade: String, $club: String,
        $lastName: String, $firstName: String, $ratingFrom: Int, $ratingTo: Int,
        $page: Int!, $limit: Int!
      ) {
        players(
          filter: {
            pin: $pin, countryCode: $countryCode, grade: $grade, club: $club,
            lastName: $lastName, firstName: $firstName,
            ratingFrom: $ratingFrom, ratingTo: $ratingTo
          }
          order: { field: pin, direction: ASC }
          pagination: { page: $page, limit: $limit }
        ) {
          data { pin firstName lastName countryCode club grade rating lastAppearance }
          hasMorePages
        }
      }
    GRAPHQL

    PLAYERS_SEARCH_QUERY = <<~GRAPHQL.freeze
      query PlayersSearch($search: String!, $page: Int!, $limit: Int!) {
        playersSearch(search: $search, order: { field: rating, direction: DESC }, pagination: { page: $page, limit: $limit }) {
          data { pin firstName lastName countryCode club grade rating }
          hasMorePages
        }
      }
    GRAPHQL

    def initialize(token: ENV["EGD_API_TOKEN"], endpoint: ENDPOINT)
      raise Error, "EGD_API_TOKEN is niet ingesteld" if token.blank?

      @token = token
      @uri = URI.parse(endpoint)
    end

    # Yields every player matching the filter, paging through the results.
    def players(filter: {}, limit: MAX_PAGE_SIZE)
      unless block_given?
        return Enumerator.new { |yielder| players(filter: filter, limit: limit) { |player| yielder << player } }
      end

      page = 1
      loop do
        variables = filter.symbolize_keys.slice(:pin, :countryCode, :grade, :club, :lastName, :firstName, :ratingFrom, :ratingTo)
        result = query(PLAYERS_QUERY, **variables, page: page, limit: limit.clamp(1, MAX_PAGE_SIZE)).fetch("players")
        result["data"].each { |player| yield player }

        break unless result["hasMorePages"]

        page += 1
      end
    end

    # Yields one page of players matching a free-text search.
    def search_players(search, limit: MAX_PAGE_SIZE)
      unless block_given?
        return Enumerator.new { |yielder| search_players(search, limit: limit) { |player| yielder << player } }
      end

      result = query(PLAYERS_SEARCH_QUERY, search: search, page: 1, limit: limit.clamp(1, MAX_PAGE_SIZE)).fetch("playersSearch")
      result["data"].each { |player| yield player }
    end

    # Posts a GraphQL document and returns its `data`, raising Egd::Error for
    # transport, HTTP, JSON and GraphQL errors alike.
    def query(document, variables = {})
      response = post(query: document, variables: variables)

      case response
      when Net::HTTPUnauthorized
        raise Error, "EGD weigert het API token (401 Unauthorized)"
      when Net::HTTPSuccess
        parse(response.body)
      else
        raise Error, "EGD antwoordde met #{response.code} #{response.message}"
      end
    end

    private
      def post(payload)
        request = Net::HTTP::Post.new(@uri)
        request["Authorization"] = "Bearer #{@token}"
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"
        request.body = payload.to_json

        Net::HTTP.start(@uri.hostname, @uri.port, use_ssl: @uri.scheme == "https",
          open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(request)
        end
      rescue SocketError, SystemCallError, Timeout::Error, IOError, OpenSSL::SSL::SSLError => error
        raise Error, "EGD is niet bereikbaar: #{error.message}"
      end

      def parse(body)
        json = JSON.parse(body.to_s)
        errors = json["errors"]
        raise Error, "EGD meldt: #{errors.filter_map { |error| error["message"] }.join(", ")}" if errors.present?

        json["data"] or raise Error, "EGD stuurde een antwoord zonder gegevens"
      rescue JSON::ParserError
        raise Error, "EGD stuurde een antwoord dat geen JSON is"
      end
  end
end
