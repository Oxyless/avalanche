module Avalanche
  class Agent
    attr_accessor :agent_id,
                  :thread_id,
                  :last_pulse,
                  :current_job,
                  :local_id,
                  :killed,
                  :timed_out

    def initialize
      self.agent_id = Random.rand(2_147_483_647)
      self.last_pulse = Time.current
    end

    def start
      self.action_loop
    end

    def pulse
      self.last_pulse = Time.current
    end

    def next_job
      next_job = Avalanche::AvalancheJob.next_job.last

      if next_job
        next_job.update_attributes({ :status => Avalanche::AvalancheJob::STATUS_RUNNING, :agent_id => self.agent_id })
      end

      next_job
    end

    def action_loop
      while 1
        puts "action_loop #{thread_id}"
        self.pulse

        job = self.next_job

        if job
          begin
            self.current_job = job
            # next_job.update_attributes({ :status => Avalanche::AvalancheJob::STATUS_KILLME })
            self.current_job.action_name.constantize.perform
            self.current_job.update_attributes({ :status => Avalanche::AvalancheJob::STATUS_DONE })
          rescue Exception => e
            self.current_job.update_attributes({ :status => Avalanche::AvalancheJob::STATUS_FAILED, :message => e.message })
          end
        else
          sleep(5)
        end
      end
    end
  end
end
