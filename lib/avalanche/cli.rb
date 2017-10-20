require_relative "agent_pool"

module Avalanche
  class Cli
    def initialize

    end

    def run
      require File.expand_path("config/environment.rb")
      ::Rails.application.eager_load!

      ::Rails.application.config.after_initialize do
        Avalanche::AvalancheJob.run_migration

        Avalanche::AvalancheJob.delete_all
        1000.times do
          Avalanche::AvalancheJob.create({ :status => Avalanche::AvalancheJob::STATUS_QUEUED, :queue => :test, :action_name => "JobTest", :action_params => "" })
        end

        agent_pool = Avalanche::AgentPool.new()
        agent_pool.start_agents
      end
    end
  end
end
