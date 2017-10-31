module Avalanche
  class Agent
    attr_accessor :agent_id,
                  :thread_id,
                  :last_pulse,
                  :current_job,
                  :local_id,
                  :killed,
                  :timed_out,
                  :profile,
                  :queues,
                  :worker_name,
                  :profile_name

    def initialize(profile)
      self.agent_id = Random.rand(2_147_483_647)
      self.last_pulse = Time.current
      self.profile = profile
      self.worker_name = self.profile["worker_name"]
      self.profile_name = self.profile["profile_name"]

      case self.profile["queues"]
      when Array
        self.queues = self.profile["queues"]
      else
        if self.profile["queues"] != "*"
          self.queues = [ self.profile["queues"] ]
        end
      end

      ap self.profile
    end

    def start
      self.action_loop
    end

    def pulse
      self.last_pulse = Time.current
    end

    def infos
      {
        :agent_id => self.agent_id,
        :queues => self.queues,
        :current_job_id => self&.current_job&.id,
        :last_pulse => self.last_pulse,
        :profile_name => self.profile_name
      }
    end

    def action_loop
      while 1
        puts "Agent loop: #{self.agent_id}"

        self.pulse
        job = Avalanche::Job.pick_job(self)

        if job
          begin
            self.current_job = job
            # next_job.update_attributes({ :status => Avalanche::Job::STATUS_KILLME })
            self.current_job.action_name.constantize.perform(*YAML::load(job.action_params))
            self.current_job.update_attributes({ :status => Avalanche::Job::STATUS_DONE })
            self.current_job = nil
          rescue Exception => e
            self.current_job.update_attributes({ :status => Avalanche::Job::STATUS_FAILED, :error_message => e.message })
            self.current_job = nil
          end
        else
          sleep(5)
        end
      end
    end
  end
end
