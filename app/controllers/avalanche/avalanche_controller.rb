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
          { title: "Message", key: "message" },
          { title: "Status", key: "status" }
      ]

      lines = all_jobs.map do |job_id, job_lines|
        job_lines.each do |line_key, line_val|
          _class = "avl-cell-color#{Avalanche::Job.queue_color(line_val)}" if line_key == :queue

          value = line_val
          value =  Avalanche::Job.pretty_status(value) if line_key == :status
          value =  YAML::load(value) if line_key == :action_params

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

    def scheduled_jobs
      scheduled_jobs = Avalanche::Job.scheduled_jobs

      columns = [
          { title: "Queue", key: "queue" },
          { title: "Job id", key: "job_id" },
          { title: "Agent id", key: "agent_id" },
          { title: "Worker name", key: "worker_name" },
          { title: "Action Name", key: "action_name" },
          { title: "Action Params", key: "action_params" },
          { title: "Created at", key: "created_at" },
          { title: "Perform at", key: "perform_at" },
          { title: "Message", key: "message" },
          { title: "Status", key: "status" }
      ]

      lines = scheduled_jobs.map do |job_id, job_lines|
        job_lines.each do |line_key, line_val|
          _class = "avl-cell-color#{Avalanche::Job.queue_color(line_val)}" if line_key == :queue

          value = line_val
          value =  Avalanche::Job.pretty_status(value) if line_key == :status
          value =  YAML::load(value) if line_key == :action_params


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

    def job_total_per_queue
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

    def job_total_per_worker_name
      job_total_per_worker_name = Avalanche::Job.job_total_per_worker_name

      columns = job_total_per_worker_name.keys.map do |worker|
        { title: worker, key: worker }
      end

      lines = []
      lines[0] = {}
      job_total_per_worker_name.keys.each do |worker|
        lines[0]["#{worker}"] = {
          :value => job_total_per_worker_name[worker][:job_total]
        }
      end

      render :json => {
        columns: columns,
        lines: lines
      }
    end

    def job_total_per_status
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
