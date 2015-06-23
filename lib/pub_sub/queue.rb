module PubSub
  class Queue
    def queue_url
      @queue_url ||= begin
        sqs.create_queue(queue_name: queue_name).queue_url
      end
    end

    def queue_arn
      @queue_arn ||= Aws::SQS::Client.new.get_queue_attributes(
        queue_url: queue_url, attribute_names: ["QueueArn"]
      ).attributes["QueueArn"]
    end

    private

    def sqs
      @sqs ||= Aws::SQS::Client.new
    end

    def queue_name
      PubSub.service_identifier
    end
  end
end
