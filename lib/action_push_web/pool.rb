module ActionPushWeb
  class Pool
    attr_reader :delivery_pool, :invalidation_pool, :connection, :invalid_subscription_handler

    def initialize(invalid_subscription_handler:)
      @delivery_pool = Concurrent::ThreadPoolExecutor.new(max_threads: 50, queue_size: 10000)
      @invalidation_pool = Concurrent::FixedThreadPool.new(1)
      @connection = Net::HTTP::Persistent.new(name: "action_push_web", pool_size: 150)
      @invalid_subscription_handler = invalid_subscription_handler
    end

    def enqueue(notification, config:)
      delivery_pool.post do
        deliver(notification, config)
      rescue Exception => e
        Rails.logger.error "Error in ActionPushWeb::Pool.deliver: #{e.class} #{e.message}"
      end
    rescue Concurrent::RejectedExecutionError
    end

    def shutdown
      connection.shutdown
      shutdown_pool(delivery_pool)
      shutdown_pool(invalidation_pool)
    end

    private

      def deliver(notification, config)
        Pusher.new(config, notification).push(connection:)
      rescue ExpiredSubscription, OpenSSL::OpenSSLError => _ex
        # Map to invalidation; SubscriptionNotification must expose subscription_id
        invalidate_subscription_later(notification.subscription_id) if invalid_subscription_handler
      end

      def invalidate_subscription_later(id)
        invalidation_pool.post do
          invalid_subscription_handler.call(id)
        rescue Exception => e
          Rails.logger.error "Error in ActionPushWeb::Pool.invalid_subscription_handler: #{e.class} #{e.message}"
        end
      end

      def shutdown_pool(pool)
        pool.shutdown
        pool.kill unless pool.wait_for_termination(1)
      end
  end
end
