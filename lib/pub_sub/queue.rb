module PubSub
  class Queue

    def list_queues
      sqs.list_queues.queue_urls
    end

    def queue_url
      @queue_url ||= begin
        sqs.create_queue(queue_name: queue_name).queue_url
      end
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
