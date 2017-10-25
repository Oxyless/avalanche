module Avalanche
  class Job
    STATUS_QUEUED     = 0
    STATUS_RUNNING    = 1
    STATUS_DONE       = 2
    STATUS_FAILED     = 3
    STATUS_DEAD       = 4
    STATUS_KILLME     = 5
    STATUS_KILLED     = 6
    STATUS_TIMEOUT    = 7
    STATUS_SCHEDULED  = 8

    def self.jobs_keys
      [
        :agent_id,
        :worker_name,
        :status,
        :queue,
        :action_name,
        :action_params,
        :perform_at,
        :created_at
      ]
    end

    def self.scheduled_jobs(limit = 5)
      AvalancheJobBasedStats.new(
          :filters => { :status => self::STATUS_SCHEDULED },
          :segmentations => [ :job_id ],
          :limit => limit
      ).get_columns(self.jobs_keys)
    end

    def self.job_total_per_queue
      AvalancheJobBasedStats.new(
          :filters => { :status => self::STATUS_QUEUED },
          :segmentations => [ :queue ]
      ).get_columns([:job_total])
    end

    def self.job_total_per_worker_name
      AvalancheJobBasedStats.new(
          :filters => { :status => self::STATUS_RUNNING },
          :segmentations => [ :worker_name ]
      ).get_columns([:job_total])
    end

    def self.job_total_per_status
      AvalancheJobBasedStats.new(
        :segmentations => [ :status ],
        :limit => 5
      ).get_columns([:job_total])
    end
  end
end
