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

    HELLO_JOB  = "HelloJob"

    def self.pretty_status(status)
      raise "status can't be nil" if status.nil?

      case status.to_i
      when self::STATUS_QUEUED
        "queued"
      when self::STATUS_RUNNING
        "running"
      when self::STATUS_DONE
        "done"
      when self::STATUS_FAILED
        "failed"
      when self::STATUS_DEAD
        "dead"
      when self::STATUS_KILLME
        "killme"
      when self::STATUS_KILLED
        "killed"
      when self::STATUS_TIMEOUT
        "timeout"
      else
        status
      end
    end

    def self.queue_color(queue)
      code = 0
      queue.each_char { |char| code += char.ord }
      return ((code % 8) + 1)
    end

    def self.jobs_keys
      [
        :job_id,
        :agent_id,
        :worker_name,
        :status,
        :queue,
        :action_name,
        :action_params,
        :perform_at,
        :created_at,
        :error_message
      ]
    end

    def self.hello_job(agent_pool)
      worker_name = agent_pool.worker_name

      job = Avalanche::AvalancheJob.where(
        :worker_name => worker_name
      ).where(
        :action_name => self::HELLO_JOB
      ).find_by_worker_name(
        worker_name
      ) || Avalanche::AvalancheJob.new

      job.worker_name = worker_name
      job.action_name = self::HELLO_JOB
      job.action_params = YAML::dump([ agent_pool.worker_name ])
      job.perform_at = Time.zone.now
      job.status = self::STATUS_DONE
      job.queue = :hello

      agents = []
      agent_pool.agents.each do |agent|
        unless agent.killed || agent.timed_out
          agents << agent.infos
        end
      end

      job.log = YAML::dump({ :agents => agents })
      job.save
    end

    def self.remove_deprecated_running_jobs(worker_name)
      Avalanche::AvalancheJob.where(
        "avalanche_jobs.status = #{self::STATUS_RUNNING}"
      ).where(
        "avalanche_jobs.worker_name = '#{worker_name}'"
      ).update_all(
        "avalanche_jobs.status = #{self::STATUS_QUEUED}, \
        avalanche_jobs.agent_id = NULL, \
        avalanche_jobs.worker_name = NULL"
      )
    end

    def self.pick_job(agent)
      job = nil

      Avalanche::AvalancheJob.transaction do
        job = Avalanche::AvalancheJob.where("avalanche_jobs.agent_id IS NULL")
        job = job.where(:status => [ self::STATUS_QUEUED ])
        job = job.perform_at_before(Time.zone.now)
        job = job.where(:queue => agent.queues) if agent.queues
        job = job.first

        if job
          job.lock!
          job.update_attributes({ :status => Avalanche::Job::STATUS_RUNNING, :worker_name => agent.worker_name, :agent_id => agent.agent_id })
        end
      end

      job
    end

    def self.set_job_status(job_id, status)
      job = Avalanche::AvalancheJob.find_by_id(job_id)

      if job
        job.status = status
        job.save
      end
    end

    def self.all_jobs(limit = 5, status: nil)
      filters = {}

      filters[:status] = status if status

      a = Avalanche::Stats::AvalancheJobBasedStats.new(
        :filters => filters,
        :segmentations => [ :job_id ],
        :limit => limit,
        :order => 'avalanche_jobs.id DESC'
      ).get_columns(self.jobs_keys).to_a.reverse.to_h
    end

    def self.scheduled_jobs(limit = 5)
      Avalanche::Stats::AvalancheJobBasedStats.new(
        :filters => { :status => self::STATUS_QUEUED },
        :segmentations => [ :job_id ],
        :limit => limit
      ).get_columns(self.jobs_keys)
    end

    def self.job_total_per_queue
      queued_jobs = Avalanche::Stats::AvalancheJobBasedStats.new(
        :filters => { :status => [ self::STATUS_QUEUED ], :perform_at_before => Time.zone.now },
        :segmentations => [ :queue ]
      ).get_columns([:job_total])

      queues = []
      log_per_worker_name = self.log_per_worker_name
      log_per_worker_name.each do |worker_name, worker_infos|
        log = YAML::load(worker_infos[:log])
        agents = log[:agents]

        agents.each do |agent|
          if agent[:queues] && agent[:queues] != "*"
            queues += agent[:queues]
          end
        end
      end

      queues.uniq.each do |queue|
        queued_jobs[queue] ||= { :job_total => 0 }
      end

      queued_jobs
    end

    def self.log_per_worker_name
      worker_logs = Avalanche::Stats::AvalancheJobBasedStats.new(
        :filters => { :perform_at_after => Time.now - 6.seconds, :action_name => [ self::HELLO_JOB ] },
        :segmentations => [ :worker_name ]
      ).get_columns([ :log ])
    end

    def self.running_agents
      running_jobs = Avalanche::Stats::AvalancheJobBasedStats.new(
        :filters => { :status => [  self::STATUS_RUNNING ]},
        :segmentations => [ :agent_id ]
      ).get_columns([ :agent_id ])

      worker_logs = self.log_per_worker_name

      agent_profile_infos = { }

      worker_logs.each do |worker_name, worker_infos|
        log = YAML::load(worker_infos[:log])
        agent_profile_infos[worker_name] ||= {}

        log[:agents].each do |agent|
          profile_name = agent[:profile_name]

          agent_profile_infos[worker_name][profile_name] ||= {
            :nb_agent => 0,
            :nb_running_job => 0,
            :queues => []
          }

          if agent[:queues]
            agent_profile_infos[worker_name][profile_name][:queues] |= agent[:queues]
          end

          agent_profile_infos[worker_name][profile_name][:nb_agent] += 1
          if running_jobs.keys.include?(agent[:agent_id])
            agent_profile_infos[worker_name][profile_name][:nb_running_job] += 1
          end
        end
      end

      agent_profile_infos
    end

    def self.job_total_per_status
      Avalanche::Stats::AvalancheJobBasedStats.new(
        :filters => { :status => [  self::STATUS_DONE, self::STATUS_FAILED, self::STATUS_DEAD, self::STATUS_KILLME, self::STATUS_KILLED, self::STATUS_TIMEOUT ]},
        :segmentations => [ :status ],
        :limit => 5
      ).get_columns([:job_total])
    end
  end
end
