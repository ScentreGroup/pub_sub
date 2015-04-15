# Pub/Sub

This gem encapsulates the common logic for publishing and subscribing to events from services.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pub_sub', git: "https://#{github_auth}@github.com/westfield/pub_sub.git"

```

And then execute:

    $ bundle


## Usage

### Configuration
Configuration is handled with an initializer as below.

```ruby
# config/initializers/pub_sub.rb
PubSub.configure do |config|
  # The name of this service
  config.service 'event'

  # Listen for the specified messages from one or more services
  config.subscribe_to 'store',  messages: ['retailer_update', 'store_update']
  config.subscribe_to 'centre', messages: ['centre_update']

  # Credentials and region for Amazon AWS (for SNS/SQS)
  config.aws(
    key: 'mykey',
    secret: 'my_secret',
    region: 'us-east-1' # Optional: us-east-1 is default
  )
end
```


### Receiving a message

When PubSub receives a message, it performs a couple of checks before processing:

* If the message originates from a service we haven't subscribed to, a `PubSub::ServiceUnknown` exception will be logged & raised.
* If the message originates from a known service, but the message type is not in the list of accepted types for that service, a `PubSub::MessageTypeUnknown` exception will be logged & raised.

If the message passes those validations, it will `classify` the message type and run its `process` method. Data from the message is available inside the message handler via the `data` variable.

```ruby
# app/events/retailer_update.rb
class RetailerUpdate
  include PubSub::MessageHandler

  def self.process(data)
  	retailer = Retailer.find_or_initialize_by(retailer_id: data['id'])
  	retailer.update(name: data['name'])
  end
end

```


### Publishing a message

A message publisher requires two things - an include of `PubSub::MessagePublisher` and a `message_data` method.

Note: If `message_data` is not defined in your publisher, a `NotImplementedError` will be raised.

```ruby
# app/events/event_update.rb
class EventUpdate
  include PubSub::MessagePublisher

  def initialize(event)
    @event = event
  end

  def message_data
    { url: event_url, id: @event.id }
  end

  def event_url
     "https://example.com/event/#{@event.id}"
  end
end
```

### Combined Publisher / Receiver

A service can publish & consume the same kind of message.

```ruby
class EventUpdate
  include PubSub::MessagePublisher
  include PubSub::MessageHandler

  def initialize(event)
    @event = event
  end

  def message_data
    { url: event_url, id: @event.id }
  end

  def event_url
     "https://example.com/event/#{@event.id}"
  end

  # Recieve & process an event_update message
  def self.process(data)
    data = Retailer.find_or_initialize_by(data_id: data['id'])
    data.update(name: data['name'])
  end
end
```

### Async
`MessagePublisher.publish` has an optional parameter `async` which will send the message in a separate thread. This avoids blocking when communicating with the Amazon SNS service which generally adds a delay of around 0.5-2 seconds. This can cause slow response times for `POST` and `PUT` requests.

The trade-off is that if a message fails to send for some reason, it won't fail the parent transaction and you won't be notified. For this reason `async` is off by default, but you can use it where it makes sense to.

```ruby
# Example of using a message publisher with async
EventUpdate.new(Event.first).publish(async: true)
```

### ActiveRecord integration

To automatically publish a message when its data changes, add the following to your model definition:

```
class Retailer < ActiveRecord::Base
  publish_changes_with :retailer_update, async: true
end
```

### Rake tasks

There are a few rake tasks made available for working with the message queues and subscriptions.

* `rake pub_sub:poll` - this task will receive messages from the queue(s) and dispatch them to the appropriate handler if one can be found. It is multi-threaded with 2 threads by default, but this can be changed by setting the `PUB_SUB_WORKER_CONCURRENCY` environment variable.

* `rake pub_sub:subscribe` - this task will subscribe the service to the message queues specified in the config.

* `rake pub_sub:debug` - this will print out information about the state of queues, topics & subscriptions.


### Errors

There are two custom exceptions which may be raised during processing:

* `PubSub::ServiceUnknown` will be raised when a message arrives but the origin service is not configured in the initializer block (via `config.subscribe_to`)
* `PubSub::MessageTypeUnknown` will be raised if a message arrives from a configured service, but is *not* in the list of acceptable messages.
