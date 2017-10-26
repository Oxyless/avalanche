class AvalancheJobBasedStats < BasedStats
  def initialize(filters: {}, dates: nil, segmentations: [], order: nil, limit: nil, coef_mark: "mark*1", round_rate: 0, round_mark: 2, per_page: nil)
    super(:filters => filters, :dates => dates, :segmentations => segmentations, :order => order, :limit => limit, :coef_mark => coef_mark, :round_rate => round_rate, :round_mark => round_mark, :per_page => per_page)

    @order = order
    @limit = limit
  end

  def build_query(columns, date: @dates.last)
    request = self.request_filters(date)
    request = self.segmentation_select(request)

    columns.each do |column|
      valid_column = true

      case column
      when :job_total
        request = request.select("COUNT(avalanche_jobs.id)")
      when :job_id
        request = request.select("MAX(avalanche_jobs.id)")
      when :agent_id
        request = request.select("MAX(avalanche_jobs.agent_id)")
      when :worker_name
        request = request.select("MAX(avalanche_jobs.worker_name)")
      when :status
        request = request.select("MAX(avalanche_jobs.status)")
      when :queue
        request = request.select("MAX(avalanche_jobs.queue)")
      when :action_name
        request = request.select("MAX(avalanche_jobs.action_name)")
      when :action_params
        request = request.select("MAX(avalanche_jobs.action_params)")
      when :perform_at
        request = request.select("MAX(avalanche_jobs.perform_at)")
      when :created_at
        request = request.select("MAX(avalanche_jobs.created_at)")
      else
        valid_column = false
      end

      @valid_columns.delete(column) unless valid_column
    end

    self.segmentation_group(request)
  end

  protected

  def request_filters(date)
    request = Avalanche::AvalancheJob.created_between(date[:date_begin], date[:date_end])
    request = request.limit(@limit) if @limit

    if @filters[:action_name].present?
      request = request.where(:action_name => @filters[:action_name])
    end

    if @filters[:status].present?
      request = request.where(:status => @filters[:status])
    end

    if @filters[:queue]
      request = request.where(:status => @filters[:queue])
    end

    if @filters[:worker_name]
      request = request.where(:status => @filters[:worker_name])
    end

    request
  end

  def segmentation_select(request)
    @segmentations.each do |segmentation|
      case segmentation
      when :job_id
        request = request.select('avalanche_jobs.id')
      when :action_name
        request = request.select('avalanche_jobs.action_name')
      when :worker_name
        request = request.select('avalanche_jobs.worker_name')
      when :status
        request = request.select('avalanche_jobs.status')
      when :queue
        request = request.select('avalanche_jobs.queue')
      end
    end

    request
  end

  def segmentation_group(request)
    groups = []

    @segmentations.each do |segmentation|
      case segmentation
        when :job_id
          groups << 'avalanche_jobs.id'
        when :action_name
          groups << 'avalanche_jobs.action_name'
        when :worker_name
          groups << 'avalanche_jobs.worker_name'
        when :status
          groups << 'avalanche_jobs.status'
        when :queue
          groups << 'avalanche_jobs.queue'
        end
    end

    request.group(groups.join(','))
  end

  def self.available_columns(columns = nil)
    [
      :job_total,
      :agent_id,
      :status,
      :queue,
      :worker_name,
      :action_name,
      :action_params,
      :perform_at,
      :created_at,
      :job_id
    ]
  end

  def self.available_filters
    [
      :worker_name,
      :action_name,
      :status,
      :queue
    ]
  end

  def self.available_segmentations
    [
      :job_id,
      :worker_name,
      :action_name,
      :status,
      :queue
    ]
  end
end
