module ActiveRecordExtension

  extend ActiveSupport::Concern

  def group_by_n_field(nb_field, *keys)
    ActiveRecord::Base.connection.execute(self.to_sql).inject({}) do |result, line|
      result_last = nb_field.times.inject(result) { |res, idx| res[line[idx]] ||= {}; res[line[idx]] }

      line[nb_field..-1].each_with_index do |val, idx|
        result_last[keys[idx]] = val
      end

      result
    end
  end

  module ClassMethods

  end
end

ActiveRecord::Relation.send(:include, ActiveRecordExtension)
