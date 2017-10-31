module Avalanche
  class AvalancheController < ApplicationController
    def index
    end

    def mockup
    end

    def all_jobs
      all_jobs = Avalanche::Job.all_jobs(10)

      columns = [
          { title: "Queue", key: "queue" },
          { title: "Job id", key: "job_id" },
          { title: "Agent id", key: "agent_id" },
          { title: "Worker name", key: "worker_name" },
          { title: "Action Name", key: "action_name" },
          { title: "Action Params", key: "action_params" },
          { title: "Created at", key: "created_at" },
          { title: "Perform at", key: "perform_at" },
          { title: "Error", key: "error_message" },
          { title: "Status", key: "status" }
      ]

      lines = all_jobs.map do |job_id, job_lines|
        job_lines.each do |line_key, line_val|
          _class = "avl-cell-color#{Avalanche::Job.queue_color(line_val)}" if line_key == :queue

          value = line_val
          value =  Avalanche::Job.pretty_status(value) if line_key == :status
          value =  YAML::load(value).join(", ") if line_key == :action_params

          job_lines[line_key] = {
            value: value,
            class: _class
          }
        end
      end

      render :json => {
        columns: columns,
        lines: lines
      }
    end

    def running_jobs
      all_jobs = Avalanche::Job.all_jobs(10, :status => [ Avalanche::Job::STATUS_RUNNING, Avalanche::Job::STATUS_KILLME ])

      columns = [
          { title: "Queue", key: "queue" },
          { title: "Job id", key: "job_id" },
          { title: "Agent id", key: "agent_id" },
          { title: "Worker name", key: "worker_name" },
          { title: "Action Name", key: "action_name" },
          { title: "Action Params", key: "action_params" },
          { title: "Created at", key: "created_at" },
          { title: "Perform at", key: "perform_at" },
          # { title: "Error", key: "error_message" },
          { title: "Status", key: "status" },
          { title: "Action", key: "action" }
      ]

      lines = all_jobs.map do |job_id, job_lines|
        job_status = nil
        job_id = nil

        job_lines.each do |line_key, line_val|
          _class = "avl-cell-color#{Avalanche::Job.queue_color(line_val)}" if line_key == :queue

          value = line_val

          if line_key == :status
            job_status = value
            value = Avalanche::Job.pretty_status(value)
          elsif line_key == :action_params
            value =  YAML::load(value).join(", ") if line_key == :action_params
          elsif line_key == :job_id
            job_id = value
          end

          job_lines[line_key] = {
            value: value,
            class: _class
          }
        end

        actions = []
        if job_status == Avalanche::Job::STATUS_RUNNING
          action = {
            target: "/avalanche/job/kill/#{job_id}",
            type: "danger",
            label: "Tuer"
          }

          actions << action
        end

        job_lines["action"] = {
          value: actions,
        }

        job_lines
      end

      render :json => {
        columns: columns,
        lines: lines
      }
    end

    def kill_job
      Avalanche::Job.set_job_status(params[:job_id], Avalanche::Job::STATUS_KILLME)

      render :json => { :status => :ok }
    end

    def jobs_to_run
      job_total_per_queue = Avalanche::Job.job_total_per_queue

      columns = job_total_per_queue.keys.map do |queue|
        { title: queue, key: queue, class:"avl-cell-color#{Avalanche::Job.queue_color(queue)}" }
      end

      lines = []
      lines[0] = {}
      job_total_per_queue.keys.each do |queue|
        lines[0]["#{queue}"] = {
          :value => job_total_per_queue[queue][:job_total]
        }
      end

      render :json => {
        columns: columns,
        lines: lines
      }
    end

    def running_jobs_overview
      running_agents = Avalanche::Job.running_agents

      columns = running_agents.keys.map do |worker_name|
        { title: worker_name, key: worker_name }
      end

      profiles = []
      running_agents.each do |worker_name, worker_infos|
        profiles |= worker_infos.keys
      end

      lines = []
      profiles.each do |profile|
        line = {}
        running_agents.each do |worker_name, worker_infos|
          html_queues = "<table style=\"width: 100%\"><tbody><tr>"
          if worker_infos[profile]
            if worker_infos[profile][:queues].present?
              worker_infos[profile][:queues].each do |queue|
                html_queues << "<td class=\"avl-cell-color#{Avalanche::Job.queue_color(queue)}\"></td>"
              end
            else
              html_queues << "<td class=\"avl-cell-color-grey\"></td>"
            end
          end
          html_queues << "</tr></tbody></table>"


          line[worker_name] = { :value => html_queues }
        end

        lines << line

        line = {}
        running_agents.each do |worker_name, worker_infos|
          if worker_infos[profile]
            line[worker_name] = { :value => "#{worker_infos[profile][:nb_running_job]} / #{worker_infos[profile][:nb_agent]}" }
          end
        end
        lines << line
      end

      render :json => {
        columns: columns,
        lines: lines
      }
    end

    def runned_jobs
      job_total_per_status = Avalanche::Job.job_total_per_status

      columns = job_total_per_status.keys.map do |status|
        { title: Avalanche::Job.pretty_status(status), key: status }
      end

      lines = []
      lines[0] = {}
      job_total_per_status.keys.each do |status|
        lines[0]["#{status}"] = {
          :value => job_total_per_status[status][:job_total]
        }
      end

      render :json => {
        columns: columns,
        lines: lines
      }
    end

    def elements
    end
  end
end
