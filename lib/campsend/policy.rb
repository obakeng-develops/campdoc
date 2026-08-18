module Campsend
  class Policy
    class Denied < StandardError
      attr_reader :outcome

      def initialize(message, outcome:)
        @outcome = outcome
        super(message)
      end
    end

    def admit_storage(user:, byte_size:)
      yield
    end

    def admit_delivery(user:)
      yield
    end

    def storage_service_name_for(user:)
    end

    def usage_for(user)
    end

    def telemetry_for(user)
      {}
    end
  end

  class << self
    attr_accessor :policy
  end

  self.policy = Policy.new
end
