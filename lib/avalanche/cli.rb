require_relative "agent_pool"

module Avalanche
  class Cli
    def initialize(argv)
      @argv = argv
    end

    def config
      config = YAML::load_file(File.join(Rails.root, 'config/avalanche.yml'))
      config ||= { "avalanche" => { } }

      @argv.each do |arg|
        if arg =~ /^--worker_name=(.*)/
          config["avalanche"]["worker_name"] = arg.gsub("--worker_name=", "")
        end
      end

      config["avalanche"]
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
           :perform_at => Time.zone.now,
           :action_params => YAML::dump([ "hello" ])
        })

        agent_pool = Avalanche::AgentPool.new(self.config)
        agent_pool.start_agents
      end
    end
  end
end
