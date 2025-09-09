module ActionPushWeb
  class Pool
    attr_reader :delivery_pool, :invalidation_pool, :connection

    def initialize
      @delivery_pool = Concurrent::ThreadPoolExecutor.new(max_threads: 50, queue_size: 10000)
      @invalidation_pool = Concurrent::FixedThreadPool.new(1)
      @connection = Net::HTTP::Persistent.new(name: "action_push_web", pool_size: 150)
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
      rescue TokenError => error
        invalidate_subscription_later(notification.subscription, error)
      end

      def invalidate_subscription_later(subscription, error)
        invalidation_pool.post do
         subscription.rescue_with_handler(error)
        rescue Exception => e
          Rails.logger.error "Error in ActionPushWeb::Pool.invalidate_subscription_later: #{e.class} #{e.message}"
        end
      end

      def shutdown_pool(pool)
        pool.shutdown
        pool.kill unless pool.wait_for_termination(1)
      end
  end
end
