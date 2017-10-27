require_relative "agent_pool"

module Avalanche
  class Cli
    def initialize

    end

    def run
      require File.expand_path("config/environment.rb")
      ::Rails.application.eager_load!

      ::Rails.application.config.after_initialize do
        Avalanche::AvalancheJob.create_table

        Avalanche::AvalancheJob.create({
           :queue => "test",
           :status => Avalanche::Job::STATUS_QUEUED,
           :action_name => "JobTest",
           :action_params => YAML::dump([ "hello" ])
        })

        config = YAML::load_file(File.join(Rails.root, 'config/avalanche.yml'))


        agent_pool = Avalanche::AgentPool.new(config["avalanche"])
        agent_pool.start_agents
      end
    end
  end
end
