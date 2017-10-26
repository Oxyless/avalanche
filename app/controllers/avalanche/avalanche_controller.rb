module Avalanche
  class AvalancheController < ApplicationController
    def index
    end

    def mockup
    end

    def scheduled_jobs
      scheduled_jobs = Avalanche::Job.scheduled_jobs

      columns = [
          { title: "Queue", key: "queue" },
          { title: "Job id", key: "job_id" },
          { title: "Agent id", key: "agent_id" },
          { title: "Worker name", key: "worker_name" },
          { title: "Status", key: "status" },
          { title: "Action Name", key: "action_name" },
          { title: "Action Params", key: "action_params" },
          { title: "Created at", key: "created_at" },
          { title: "Perform at", key: "perform_at" }
      ]

      datas = scheduled_jobs.map do |job_id, job_datas|
        job_datas.each do |datas_key, datas_val|
          _class = "avl-cell-color#{Avalanche::Job.queue_color(datas_val)}" if datas_key == :queue

          job_datas[datas_key] = {
            value: datas_val,
            class: _class
          }
        end
      end

      render :json => {
        columns: columns,
        datas: datas
      }
    end

    def job_total_per_queue
      job_total_per_queue = Avalanche::Job.job_total_per_queue

      columns = job_total_per_queue.keys.map do |queue|
        { title: queue, key: queue, class:"avl-cell-color#{Avalanche::Job.queue_color(queue)}" }
      end

      datas = []
      datas[0] = {}
      job_total_per_queue.keys.each do |queue|
        datas[0]["#{queue}"] = {
          :value => job_total_per_queue[queue][:job_total]
        }
      end

      render :json => {
        columns: columns,
        datas: datas
      }
    end

    def job_total_per_worker_name
      job_total_per_worker_name = Avalanche::Job.job_total_per_worker_name

      columns = job_total_per_worker_name.keys.map do |worker|
        { title: worker, key: worker }
      end

      datas = []
      datas[0] = {}
      job_total_per_worker_name.keys.each do |worker|
        datas[0]["#{worker}"] = {
          :value => job_total_per_worker_name[worker][:job_total]
        }
      end

      render :json => {
        columns: columns,
        datas: datas
      }
    end

    def job_total_per_status
      job_total_per_status = Avalanche::Job.job_total_per_status

      columns = job_total_per_status.keys.map do |status|
        { title: Avalanche::Job.pretty_status(status), key: status }
      end

      datas = []
      datas[0] = {}
      job_total_per_status.keys.each do |status|
        datas[0]["#{status}"] = {
          :value => job_total_per_status[status][:job_total]
        }
      end

      render :json => {
        columns: columns,
        datas: datas
      }
    end

    def elements
      planified = Avalanche::AvalancheJob.where("avalanche_jobs.perform_at > ?", Time.now)
    end
  end
end
