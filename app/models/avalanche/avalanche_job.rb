require "active_record"

module Avalanche
  class AvalancheJob < ActiveRecord::Base
    attr_accessible :queue, :perform_at, :status, :action_name, :action_params, :agent_id, :message

    STATUS_QUEUED   = 0
    STATUS_RUNNING  = 1
    STATUS_DONE     = 2
    STATUS_FAILED   = 3
    STATUS_DEAD     = 4
    STATUS_KILLME   = 5
    STATUS_KILLED   = 6
    STATUS_TIMEOUT  = 7

    def self.run_migration
      unless ActiveRecord::Base.connection.tables.include? "avalanche_jobs"
        ActiveRecord::Migration.create_table :avalanche_jobs do |t|
          t.integer :agent_id
          t.integer :status
          t.string :queue
          t.string :action_name
          t.text :action_params
          t.text :message

          t.datetime :perform_at

          t.timestamps
        end

        ActiveRecord::Migration.add_index :avalanche_jobs, :queue
      end
    end

    def self.next_job
      AvalancheJob.next_jobs(1)
    end

    def self.next_jobs(limit = 5)
      AvalancheJob.where(:status => AvalancheJob::STATUS_QUEUED)
                  .where(:queue => :test)
                  .where("avalanche_jobs.agent_id IS NULL")
                  .where("(avalanche_jobs.perform_at IS NULL OR avalanche_jobs.perform_at < \"#{Time.current.to_s(:db)}\")")
                  .limit(limit)
    end
  end
end
