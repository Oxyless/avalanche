require_relative "thread_manager"
require_relative "safe_array"
require_relative "agent"

module Avalanche
  class AgentPool
    def initialize
      @thread_manager = Avalanche::ThreadManager.new
      @agents = Avalanche::SafeArray.new
      @mutex = Mutex.new

      @total_agents = 0
      @max_agents = 3
    end

    def start_agents
      Thread.abort_on_exception = true

      begin
        @thread_manager.start_thread do
          self.agents_loop
        end

        @thread_manager.start_thread do
          self.kill_loop
        end

        @thread_manager.start_thread do
          self.timeout_loop
        end
      rescue Exception => e
        puts "EXCEPTION: #{e.inspect}"
        puts "MESSAGE: #{e.message}"
      end

      @thread_manager.join_all
    end

    def start_agent
      puts "start_agent"

      agent = Avalanche::Agent.new

      thread_id = @thread_manager.start_thread do
        agent.start
      end

      agent.thread_id = thread_id
      agent.local_id = @agents.push(agent)

      @mutex.synchronize do
        @total_agents += 1
      end

      agent
    end

    def need_agent
      @mutex.synchronize do
        @max_agents += 1
      end
    end

    def kill_agent(agent_id)
      agent = @agents.fetch { |e| e.agent_id == agent_id }

      if agent
        if @thread_manager.exit_thread(agent.thread_id)
          return agent
        end
      end

      return nil
    end

    def agents_loop
      while 1
        if @total_agents < @max_agents
          self.start_agent
        end

        sleep(1)
      end
    end

    def kill_loop
      while 1
        puts "kill_loop"

        Avalanche::AvalancheJob.where(:status => Avalanche::AvalancheJob::STATUS_KILLME)
                  .where(:queue => :test)
                  .where(:"avalanche_jobs.agent_id" => @agents.map(&:agent_id))
                  .each do |dothing_job|

          agent_killed = self.kill_agent(dothing_job.agent_id)

          if agent_killed
            dothing_job.update_attribute(:status, Avalanche::AvalancheJob::STATUS_KILLED)
            agent_killed.killed = true

            puts "#{dothing_job.agent_id} killed"
            self.need_agent
          end
        end

        sleep(5)
      end
    end

    def timeout_loop
      while 1
        puts "timeout_loop"

        @agents.each do |agent|
          next if agent.timed_out
          next if agent.killed

          current_time = Time.current

          if current_time - agent.last_pulse > 30
            agent_killed = self.kill_agent(agent.agent_id)

            if agent_killed
              if agent.current_job
                agent_killed.current_job.update_attribute(:status, Avalanche::AvalancheJob::STATUS_TIMEOUT)
                agent_killed.timed_out = true

                puts "#{agent.agent_id} timed_out"
                self.need_agent
              end
            end
          end
        end

        sleep(10)
      end
    end
  end
end

# ActiveRecord::Base.establish_connection({:adapter => "mysql", :database => new_name, :host => "olddev",
#     :username => "root", :password => "password" })
