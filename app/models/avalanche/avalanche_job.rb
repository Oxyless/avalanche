require "active_record"

module Avalanche
  class AvalancheJob < ActiveRecord::Base
    attr_accessible :queue,
                    :perform_at,
                    :status,
                    :action_name,
                    :action_params,
                    :agent_id,
                    :error_message,
                    :log,
                    :worker_name

    scope :created_between, -> (start_date, end_date) { created_after(start_date).created_before(end_date) }
    scope :created_before, -> (date) { (date ? where("avalanche_jobs.created_at <= ?", date) : scoped) }
    scope :created_after, -> (date) { (date ? where("avalanche_jobs.created_at >= ?", date) : scoped) }

    scope :perform_at_between, -> (start_date, end_date) { perform_at_after(start_date).perform_at_before(end_date) }
    scope :perform_at_before, -> (date) { (date ? where("avalanche_jobs.perform_at <= ?", date) : scoped) }
    scope :perform_at_after, -> (date) { (date ? where("avalanche_jobs.perform_at >= ?", date) : scoped) }

    def kill_me
      self.update_attribute(:status, Avalanche::Job::STATUS_KILLME)
    end

    def self.create_table
      unless ActiveRecord::Base.connection.tables.include? "avalanche_jobs"
        ActiveRecord::Migration.create_table :avalanche_jobs do |t|
          t.string   :queue
          t.integer  :status
          t.string   :action_name
          t.text     :action_params
          t.string   :worker_name
          t.integer  :agent_id
          t.text     :error_message
          t.text     :log

          t.datetime :perform_at

          t.timestamps
        end

        ActiveRecord::Migration.add_index :avalanche_jobs, :queue
        ActiveRecord::Migration.add_index :avalanche_jobs, :worker_name
      end
    end

    def self.drop_table
      if ActiveRecord::Base.connection.tables.include? "avalanche_jobs"
        ActiveRecord::Migration.drop_table :avalanche_jobs
      end
    end

    def self.test_table
      queues = [ :soft, :medium, :hard ]
      workers = {
         :worker_1 => [ Random.rand(2_147_483_647), Random.rand(2_147_483_647), Random.rand(2_147_483_647), Random.rand(2_147_483_647) ],
         :worker_2 => [ Random.rand(2_147_483_647), Random.rand(2_147_483_647), Random.rand(2_147_483_647), Random.rand(2_147_483_647) ],
         :worker_3 => [ Random.rand(2_147_483_647), Random.rand(2_147_483_647), Random.rand(2_147_483_647), Random.rand(2_147_483_647) ],
         :worker_4 => [ Random.rand(2_147_483_647), Random.rand(2_147_483_647), Random.rand(2_147_483_647), Random.rand(2_147_483_647) ]
       }

      Avalanche::AvalancheJob.delete_all

      [1,2,3,4,5,6,7,8,9,10].each do |n|
        Avalanche::AvalancheJob.create({
           :queue => queues.sample,
           :status => Avalanche::Job::STATUS_SCHEDULED,
           :action_name => "JobTest",
           :action_params => "42",
           :perform_at => Time.now + n.days
        })
      end

      [1,2,3,4,5,6,7,8,9,10].each do |n|
        Avalanche::AvalancheJob.create({
           :queue => queues.sample,
           :status => Avalanche::Job::STATUS_QUEUED,
           :action_name => "JobTest",
           :action_params => "42"
        })
      end

      [1,2,3,4,5,6,7,8,9,10].each do |n|
        worker_name = workers.keys.sample

        Avalanche::AvalancheJob.create({
           :queue => queues.sample,
           :status => Avalanche::Job::STATUS_RUNNING,
           :action_name => "JobTest",
           :action_params => "42",
           :worker_name => worker_name,
           :agent_id => workers[worker_name].sample
        })
      end

      exec_status =[ Avalanche::Job::STATUS_DONE,
      Avalanche::Job::STATUS_FAILED,
      Avalanche::Job::STATUS_TIMEOUT,
      Avalanche::Job::STATUS_DEAD,
      Avalanche::Job::STATUS_KILLED,
      Avalanche::Job::STATUS_KILLME ]

      [1,2,3,4,5,6,7,8,9,10].each do |n|
        worker_name = workers.keys.sample
        status = exec_status.sample
        message = nil

        if exec_status == Avalanche::Job::STATUS_FAILED
          message = "Attribute was supposed to be a Array, but was a ActiveSupport::HashWithIndifferentAccess"
        end

        Avalanche::AvalancheJob.create({
           :queue => queues.sample,
           :status => status,
           :action_name => "JobTest",
           :action_params => "42",
           :worker_name => worker_name,
           :message => message,
           :agent_id => workers[worker_name].sample
        })
      end

      Avalanche::AvalancheJob.count
    end
  end
end
