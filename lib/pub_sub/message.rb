module PubSub
  class Message
    def initialize(payload)
      @payload = JSON.parse(payload)
    end

    def process
      validate_message!
      handler.process
    end

    def validate_message!
      messages = PubSub.config.subscriptions[sender]
      if messages.nil?
        error = "We received a message from #{sender} but we do " \
                'not subscribe to that service.'
        PubSub.logger.error(error)
        fail PubSub::ServiceUnknown, error
      end

      unless messages.include?(type)
        error = "We received a message from #{sender} but it was " \
                "of unknown type #{type}."
        PubSub.logger.error(error)
        fail PubSub::MessageTypeUnknown, error
      end
    end

    private

    # Service where this message originated
    def sender
      @payload['sender']
    end

    def type
      @payload['type']
    end

    def handler
      type.camelize.constantize.new(@payload['data'])
    end
  end
end
