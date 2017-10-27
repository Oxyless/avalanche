require_relative "thread_manager"
require_relative "safe_array"
require_relative "agent"

module Avalanche
  class AgentPool
    def initialize(config)
      @thread_manager = Avalanche::ThreadManager.new
      @agents = Avalanche::SafeArray.new
      @mutex = Mutex.new

      @required_agents = []
      @total_agents = 0

      config["pool"].each do |p_id, p_config|
        p_config["agents"].times do
          p_config["profile"]["worker_name"] = config["worker_name"]
          self.need_agent(p_config["profile"])
        end
      end
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

    def start_agent(profile)
      @mutex.synchronize do
        @total_agents += 1
      end

      agent = Avalanche::Agent.new(profile)
      agent.profile = profile

      puts "Agent loaded #{agent.agent_id}: #{profile}"
      thread_id = @thread_manager.start_thread do
        agent.start
      end

      agent.thread_id = thread_id
      agent.local_id = @agents.push(agent)

      agent
    end

    def need_agent(profile)
      @mutex.synchronize do
        @required_agents << profile
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
        if @total_agents < @required_agents.size
          self.start_agent(@required_agents[@total_agents])
        end

        sleep(1)
      end
    end

    def kill_loop
      while 1
        puts "Kill loop"

        Avalanche::AvalancheJob.where(:status => Avalanche::Job::STATUS_KILLME)
                  .where(:queue => :test)
                  .where(:"avalanche_jobs.agent_id" => @agents.map(&:agent_id))
                  .each do |dothing_job|

          agent_killed = self.kill_agent(dothing_job.agent_id)

          if agent_killed
            dothing_job.update_attribute(:status, Avalanche::Job::STATUS_KILLED)
            agent_killed.killed = true

            puts "Agent #{dothing_job.agent_id} killed"
            self.need_agent(agent_killed.profile)
          end
        end

        sleep(5)
      end
    end

    def timeout_loop
      while 1
        puts "Timeout loop"

        @agents.each do |agent|
          next if agent.timed_out
          next if agent.killed

          current_time = Time.current

          if current_time - agent.last_pulse > 60
            agent_killed = self.kill_agent(agent.agent_id)

            if agent_killed
              if agent.current_job
                agent_killed.current_job.update_attribute(:status, Avalanche::Job::STATUS_TIMEOUT)
                agent_killed.timed_out = true

                puts "Agent #{agent.agent_id} timed_out"
                self.need_agent(agent_killed.profile)
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
