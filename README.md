# ActionPushWeb

Action Push Web is a Rails push notification gem for the web and PWAs.

## Installation

```bash
1. bundle add action_push_web
2. bin/rails g action_push_web:install
4. bin/rails db:migrate
```

This will install the gem and run the necessary migrations to set up the database.

The install generator will also output a generated public and private key that
you'll want to add to your credentitals.

## Configuration

The installation will create:

- `app/models/application_push_web_notification.rb`
- `app/jobs/application_push_web_notification_job.rb`
- `app/models/application_push_subscription.rb`
- `config/push.yml`
- `app/views/pwa/service_worker.js`
- mount the subscriptions controllers
- import action_push_web.js in your application.js


`app/models/application_push_web_notification.rb`:
```ruby
class ApplicationPushWebNotification < ActionPushWeb::Notification
  # Set a custom job queue_name
  queue_as :realtime

  # Controls whether push notifications are enabled (default: !Rails.env.test?)
  self.enabled = Rails.env.production?

  # Define a custom callback to modify or abort the notification before it is sent
  before_delivery do |notification|
    throw :abort if Notification.find(notification.context[:notification_id]).expired?
  end
end
```

Used to create and send push notifications. You can customize it by subclassing or
you can change the application defaults by editing it directly.

`app/jobs/application_push_web_notification_job.rb`:

```ruby
class ApplicationPushWebNotificationJob < ActionPushWeb::NotificationJob
  # Enable logging job arguments (default: false)
  self.log_arguments = true

  # Report job retries via the `Rails.error` reporter (default: false)
  self.report_job_retries = true
end
```

Job class that processes the push notifications. You can customize it by editing it
directly in your application.

`app/models/application_push_subscription.rb`:

```ruby
class ApplicationPushSubscription < ActionPushWeb::Subscription
  # Customize TokenError handling (default: destroy!)
  # rescue_from (ActionPushWeb::TokenError) { Rails.logger.error("Subscription #{id} token is invalid") }
end
```

This represents a push notification subscription. You can customize it by editing it directly in your application.

`config/push.yml`:

```yaml
shared:
  web:
    public_key: <%= Rails.application.credentials.action_push_web.public_key %>
    private_key: <%= Rails.application.credentials.action_push_web.private_key %>

    # Change the request timeout (default: 30).
    # request_timeout: 60

    # Change the ttl (default: 2419200).
    # ttl: 60

    # Change the expiration (default: 43200).
    # expiration: 60

    # Change the subject (default: mailto:sender@example.com).
    # expiration: mailto:support@my-domain.com

    # Change the urgency (default: normal). You also choose to set this at the notification level.
    # urgency: high
```

This file contains the configuration for the push notification services you want to use.
The push notification requires a web key with a public and private key.
If you're configuring more than one app, see the section [Configuring multiple apps](#configuring-multiple-apps) below.

### Configuring multiple apps

You can send push notifications to multiple apps using different notification classes.
Each notification class need to inherit from `ApplicationPushWebNotification` and set `self.application`, to a key set in `push.yml`
for each supported platform. You can also (optionally) set a shared `application` option in `push.yml`.
This acts as the base configuration for that platform, and its values will be merged (and overridden) with the matching app-specific configuration.

In the example below we are configuring two apps: `calendar` and `email` using respectively the
`CalendarPushNotification` and `EmailPushNotification` notification classes.

```ruby
class CalendarPushNotification < ApplicationPushWebNotification
  self.application = "calendar"

  # Custom notification logic for calendar app
end

class EmailPushNotification < ApplicationPushWebNotification
  self.application = "email"

  # Custom notification logic for email app
end
```

```yaml
shared:
  web:
    # Base configuration for web platform
    # This will be merged with the app-specific configuration
    application:
      request_timeout: 60

    calendar:
      public_key: <%%= Rails.application.credentials.action_push_web.calendar.public_key %>
      private_key: <%%= Rails.application.credentials.action_push_web.calendar.private_key %>

    email:
      public_key: <%%= Rails.application.credentials.action_push_web.email.public_key %>
      private_key: <%%= Rails.application.credentials.action_push_web.email.private_key %>
```

## Usage

### Create and send a notification asynchronously to a subscription

```ruby
subscription = ApplicationPushSubscription.create! \
  user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1",
  auth_key: "foStsVKvFCvKS1KJF4OaDS",
  p256dh_key: "8YZosOgeQYI1lXr6Enahllf56j0VvEynIIm0q37k19QdbclLPNbACud8XSgS1b04TNAFlwyS1niwMx9LoLp8Hsx",
  endpoint: "https://web.push.apple.com/2UtCfdxa01DJYCW0R7qnA9u4JqYnYo5CHSlR0b95JnMhAW1Zy32ZN9BTLY8KLXogMU3EMuYDWNgdUcX8OaNEZCQOhFp7zeo8US2ZvKYdvGxAjx1ELZH9e3yXHEYlco6vKLfsgOCZxabp63rt80voC5n9i6IzAvMgWmcwz5INfBd"

notification = ApplicationPushWebNotification.new \
  title: "Hello world!",
  body:  "Welcome to Action Push Web",
  path:  "/welcome"

notification.deliver_later_to(subscription)
```

`deliver_later_to` supports also an array of devices:

```ruby
notification.deliver_later_to([ subscription1, subscription2 ])
```

A notification can also be delivered synchronously using `deliver_to`:

```ruby
notification.deliver_to(subscription)
```

It is recommended to send notifications asynchronously using `deliver_later_to`.
This ensures error handling and retry logic are in place, and avoids blocking your application's execution.

### Linking a Subscription to a Record

A Subscription can be associated with any record in your application via the `owner` polymorphic association:

```ruby
user = User.find_by_email_address("pezza@hey.com")

ApplicationPushSubscription.create! \
  user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1",
  auth_key: "foStsVKvFCvKS1KJF4OaDS",
  p256dh_key: "8YZosOgeQYI1lXr6Enahllf56j0VvEynIIm0q37k19QdbclLPNbACud8XSgS1b04TNAFlwyS1niwMx9LoLp8Hsx",
  endpoint: "https://web.push.apple.com/2UtCfdxa01DJYCW0R7qnA9u4JqYnYo5CHSlR0b95JnMhAW1Zy32ZN9BTLY8KLXogMU3EMuYDWNgdUcX8OaNEZCQOhFp7zeo8US2ZvKYdvGxAjx1ELZH9e3yXHEYlco6vKLfsgOCZxabp63rt80voC5n9i6IzAvMgWmcwz5INfBd",
  owner: user
```

### `before_delivery` callback

You can specify Active Record like callbacks for the `delivery` method. For example, you can modify
or cancel the notification by specifying a custom `before_delivery` block. The callback has access
to the `notification` object. You can also pass additional context data to the notification
by adding extra arguments to the notification constructor:

```ruby
class CalendarPushNotification < ApplicationPushWebNotification
  before_delivery do |notification|
    throw :abort if Calendar.find(notification.context[:calendar_id]).expired?
  end
end

notification = CalendarPushNotification
  .new(title: "Upcoming event", path: "/events/1", calendar_id: 123)

notification.deliver_later_to(subscription)
```

### Using a custom Subscription model

If using the default `ApplicationPushSubscription` model does not fit your needs, you can create a custom
subscription model, as long as:

1. It can be serialized and deserialized by `ActiveJob`.
2. It responds to the `endpoint`, `auth_key` and `p256dh_key` methods.
3. It implements a `push` method like this:

```ruby
class CustomSubscription
  # Your custom device attributes and methods...

  def push(notification)
    ActionPushWeb.push \
      ActionPushWeb::SubscriptionNotification.new(notification:, subscription: self)
  end
end
```

On the frontend, there are 3 custom HTML elements that can be accessed via helpers.

The first is when the user has not yet granted permission to send notifications.

You can use what ever HTML you want inside these components. Once the user either grants or denies
permission the component will hide itself.

```erb
<%= ask_for_web_notifications do %>
  <div class="text-blue">Request permission</div>
<% end %>
```

If a user denies permission to send notifications:

```erb
<%= when_web_notifications_disabled do %>
  <div class="text-red">Notifications aren’t allowed</div>
<% end %>
```

And if a user grants permission to send notifications.
It accepts an `href` attribute to be passed to the helper that points to a create
action that handles creating a push subscription. By default it points to the
controller included in ActionPushWeb, `action_push_web.subscriptions_path`. It
also accepts a `service_worker_url` attribute that points to the service worker.
By default it points to `pwa_service_worker_path(format: :js)`

```erb
<%= when_web_notifications_allowed href: action_push_web.subscriptions_path, class: "text-green" do %>
  Notifications are allowed
<% end %>
```

You can alternatively create a custom controller that handles creating a push subscription:

```ruby
class PushSubscriptionsController < ActionPushWeb::SubscriptionsController
  private
    def push_subscription_params
      super.merge(owner: Current.user)
    end
end
```

```erb
<%= ask_for_web_notifications(href: push_subscriptions_path) do %>
  <div class="text-blue">Request permission</div>
<% end %>
```

## `ActionPushWeb::Notification` attributes

| Name           | Description
|------------------|------------
| :title           | The title of the notification.
| :body            | The body of the notification.
| :badge           | The badge number to display on the app icon.
| :path            | The path to open when the user taps on the notification.
| :icon_path       | The path to the icon to display in the notification.
| :urgency         | The urgency of the notification. (very-low \| low \| normal \| high)
| **               | Any additional attributes passed to the constructor will be merged in the `context` hash.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
