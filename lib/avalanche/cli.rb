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

        agent_pool = Avalanche::AgentPool.new()
        agent_pool.start_agents
      end
    end
  end
end
