require_relative "safe_array"

module Avalanche
  class ThreadManager
    def initialize
      @threads = Avalanche::SafeArray.new
    end

    def start_thread(&block)
      new_thread = Thread.new {
        yield
      }

      thread_id = @threads.push(new_thread)
      thread_id
    end

    def join_all
      @threads.each do |thread|
        thread.join
      end
    end

    def exit_thread(thread_id)
      if @threads[thread_id]
        @threads[thread_id].exit()
        return true
      else
        return false
      end
    end
  end
end
