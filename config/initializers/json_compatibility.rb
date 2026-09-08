module ActiveSupport
  module JSON
    class << self
      def decode(json, options = {})
        data = ::JSON.parse(json, **options)

        ActiveSupport.parse_json_times ? convert_dates_from(data) : data
      end
      alias_method :load, :decode
    end
  end
end
