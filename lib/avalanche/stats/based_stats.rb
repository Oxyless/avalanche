module Avalanche
  module Stats
    class BasedStats
      class TypeError < StandardError ; end

      attr_reader :identifier
      attr_reader :datas

      def self.get(
        filters: {},
        dates: [ { :label => :genesis } ],
        segmentations: [],
        order: "",
        limit: nil,
        coef_mark: "mark*1",
        round_rate: 0,
        round_mark: 2,
        per_page: nil
      )
        stats_instance = if self.to_s == 'CombinedStats'
                           self.new(:filters => filters, :dates => dates, :segmentations => segmentations, :order => order, :coef_mark => coef_mark, :round_rate => round_rate, :round_mark => round_mark, :per_page => per_page)
                         else
                           self.new(:filters => filters, :dates => dates, :segmentations => segmentations, :order => order, :limit => nil, :coef_mark => coef_mark, :round_rate => round_rate, :round_mark => round_mark, :per_page => per_page)
                         end

        return stats_instance
      end

      def initialize(
        filters: {},
        dates: [ { :label => :genesis } ],
        segmentations: [],
        order: "",
        limit: nil,
        coef_mark: 1,
        round_rate: 0,
        round_mark: 2,
        per_page: nil
      )
        filters.symbolize_keys!
        segmentations.map!(&:to_sym)

        @coef_mark = coef_mark
        @per_page = per_page
        @filters = {}
        @columns = {}
        @datas = {}
        @total_page = {}

        @round_rate = round_rate
        @round_mark = round_mark

        set_segmentations(segmentations)
        set_filters(filters)
        set_dates(dates)

        @identifier = self.class.name + @filters.to_s + @dates.to_s + @segmentations.to_s + order.to_s + limit.to_s + coef_mark.to_s + @round_rate.to_s + @round_mark.to_s + @per_page.to_s
      end

      public

      # see available_columns
      #
      def get_columns(columns, date_label: @dates.last[:label], compare_with: nil, sort_by: [], format: :hash)
        columns += sort_by.reject{ |s| [:DESC, :ASC].include?(s) || s =~ /^(.*)_evolution$/ }
        columns = columns.compact.uniq

        self.check_colums(columns)

        data_label = date_label
        data_label = "#{date_label}_compared_with_#{compare_with}" if compare_with.present?
        data_label = "#{data_label}_sorted_by_#{sort_by.join('_')}" if sort_by.present?

        @valid_columns = (columns - @columns[data_label]) rescue columns
        @columns[data_label] ||= []
        @datas[data_label] ||= {}

        return @datas[data_label] if (columns - Array(@columns[data_label])).empty?

        date =  @hash_dates[date_label]
        query = self.build_query(columns - @columns[data_label], :date => date)
        return query.to_sql if format.to_s.to_sym == :sql
        @datas[data_label].deep_merge!(resolve_query(query))

        if compare_with
          self.compare_hash(@datas[data_label], self.get_columns(columns, date_label: compare_with))
        end
        @columns[data_label] |= columns

        self.apply_sort_by(@datas, data_label, sort_by)

        case format
        when :hash
          @datas[data_label]
        when :csv
          self.hash_to_csv(@datas[data_label], columns, compare_with: compare_with)
        end
      end

      def get_columns_with_pages(columns, page, date_label: @dates.last[:label], compare_with: nil, sort_by: [])
        columns = columns.compact.uniq

        raise StandardError.new('Cannot use pagination without a per_page parameter in constructor') unless @per_page
        self.check_colums(columns)

        data_label = page ? "#{page}_#{date_label}" : date_label
        data_label = "#{data_label}_compared_with_#{compare_with}" if compare_with
        data_label = "#{data_label}_sorted_by_#{sort_by.join('_')}" if sort_by.present?

        @valid_columns = (columns - @columns[data_label]) rescue columns
        @columns[data_label] ||= []
        @datas[data_label] ||= {}

        return [@datas[data_label], @total_page[data_label]] if (columns - Array(@columns[data_label])).empty?

        date =  @hash_dates[date_label]
        query = self.build_query(columns - @columns[data_label], :date => date)

        total_pages = nil
        if @segmentations.count == 0
          total_pages = (@total_page[data_label] || (query.except(:select).select("COUNT(*) AS nb_elem")[0][:nb_elem] / @per_page.to_f).ceil)
          query = query.limit(@per_page).offset(@per_page * (page - 1))
          @datas[data_label].deep_merge!(resolve_query(query))
        elsif @segmentations.count == 1
          total_pages = (@total_page[data_label] || (query.except(:select).except(:group).select("COUNT(DISTINCT(#{self.extract_first_selected_column(query)})) AS nb_elem")[0][:nb_elem] / @per_page.to_f).ceil)
          query = query.limit(@per_page).offset(@per_page * (page - 1))
          @datas[data_label].deep_merge!(resolve_query(query))
        else
          total_pages = (@total_page[data_label] || (resolve_query(query).count / @per_page.to_f).ceil)
          query_hash = resolve_query(query)
          query_hash = query_hash.slice(*query_hash.keys.slice(@per_page * (page - 1), @per_page))
          @datas[data_label].deep_merge!(query_hash)
        end

        if compare_with
          self.compare_hash(@datas[data_label], self.get_columns(columns, date_label: compare_with))
        end
        @columns[data_label] |= columns

        self.apply_sort_by(@datas, data_label, sort_by)
        @total_page[data_label] = total_pages

        [@datas[data_label], @total_page[data_label]]
      end

      protected

      def extract_first_selected_column(query)
        pos = 0
        bracket = 0
        query_sql = query.to_sql.gsub("SELECT ", "")

        query_sql.each_char do |c|
        	if bracket == 0 && [" ", ","].include?(c)
        		break
        	elsif c == "("
        		bracket += 1
        	elsif c == ")"
        		bracket -= 1
        	end

          pos += 1
        end

        query_sql[0...pos].strip
      end

      def apply_sort_by(datas, data_label, sort_by)
        if sort_by.present? && @segmentations.size == 1
          sort_direction = :DESC if sort_by[-1] == :DESC
          sort_by = sort_by[0..-2] if [:DESC, :ASC].include?(sort_by[-1])

          sort_by_classes = begin
            sort_by.map do |sort_by_column|
              [
                sort_by_column,
                datas[data_label].detect{ |_, item| item[sort_by_column].present? }.last[sort_by_column].class
              ]
            end.to_h
          rescue
            {}
          end

          data_sorted = datas[data_label].sort_by do |key, values|
            sort_by.inject([]) do |elem, sort_by_column|
              new_elem = values[sort_by_column]
              new_elem ||= if sort_by_classes[sort_by_column] == String
                sort_direction == :ASC ? '' : '~~~~~~~~'
              else
                sort_direction == :ASC ? Numeric::MAX : -Numeric::MAX
              end
              elem << new_elem
              elem
            end
          end

          data_sorted = data_sorted.reverse if sort_direction == :DESC
          datas[data_label] = Hash[data_sorted]
        end
      end

      def resolve_query(query)
        return (@valid_columns.empty? ? {} : query.group_by_n_field(self.segmentation_keys.count, *@valid_columns))
      end

      # setters
      def set_segmentations(_segmentations)
        self.check_segmentations(_segmentations)

        @segmentations = _segmentations
      end

      def set_dates(_dates)
        self.check_dates(_dates)

        case _dates
          when Hash
            @dates = [ _dates.merge({ :label => :mono }) ]
          when Array
            @dates = _dates
          when NilClass
            @dates = [ { :label => :genesis } ]
        end

        @hash_dates = @dates.inject({}) do |res, d|
          raise StandardError.new("You have to specify label for dates") unless d[:label]

          d.symbolize_keys!

          res[d[:label]] = d
          res
        end
      end

      def convert_in_array(target)
        case target
          when String
            target.split(',').collect(&:strip)
          when Integer, Numeric
            [target]
          when Array
            target
          when ActiveRecord::Relation
            target.collect(&:id)
          else
            raise StandardError.new("Invalid type: #{target.class}: #{target.to_s}")
        end
      end

      def set_filters(_filters, check: true)
        self.check_filters(_filters) if check == true

        _filters.each do |name, target|
          @filters[name] = target
        end


        @filters = @filters.sort.to_h
      end

      # checks
      def check_segmentations(_segmentations)
        diff_column = (_segmentations.collect do |_segmentation|
          _segmentation.to_s.to_sym
        end.uniq - self.class.available_segmentations)

        if diff_column.size == 0
          return true
        else
          raise StandardError.new("#{self.class.name}: Bad segmentations: #{diff_column.join(', ')}: see available_segmentations")
          return false
        end
      end

      def check_filters(_filters)
        diff_column = (_filters.keys - self.class.available_filters )

        if diff_column.size == 0
          return true
        else
          raise StandardError.new("Bad filters: #{diff_column.join(', ')}: see available_filters")
          return false
        end
      end

      def check_dates(_dates)

      end

      def available_columns(columns = nil)
        self.class.available_columns(columns)
      end

      def update_available_columns(columns)

      end

      def check_colums(columns)
        self.update_available_columns(columns)
        diff_column = (columns - self.class.available_columns(columns))

        if diff_column.size == 0
          return true
        else
          raise StandardError.new("Bad columns: #{diff_column.join(', ')}: see available_columns")
          return false
        end
      end

      #
      def segmentation_keys
        @segmentations
      end

      # utils
      def compare_hash(hash1, hash2, path = "")
        hash1.keys.each do |key|
          value = hash1[key]
          case value
            when Hash
              case key
                when Integer
                  compare_hash(value, hash2, path + "[#{key}]")
                when Symbol
                  compare_hash(value, hash2, path + "[:#{key}]")
                when String
                  compare_hash(value, hash2, path + "['#{key}']")
              end
            when Float, BigDecimal
              hash2_value = eval("hash2#{path}")[key] rescue nil
              hash1[:"#{key}_evolution"] = (hash1[key] - hash2_value).round((key =~ /rate/ ? @round_rate : @round_mark)) rescue nil
              hash1[:"#{key}_compared"] = hash2_value
            when Integer, Fixnum
              hash2_value = eval("hash2#{path}")[key] rescue nil
              hash1[:"#{key}_evolution"] = (hash1[key] - hash2_value) rescue nil
              hash1[:"#{key}_compared"] = hash2_value
          end
        end
      end

      def scalar_check(label, target, types)
        types = [ types ] unless types.is_a?(Array)

        unless types.include?(target.class)
          raise TypeError.new("#{label} must be a #{types} : got #{target.class}")
        end
      end

      def array_check(label, target, types)
        raise TypeError.new("#{label} must be an array of #{types} : got #{target.class}") unless target.is_a?(Array)

        types = [ types ] unless types.is_a?(Array)

        unless types.include?(target.first.class) or target.empty?
          raise TypeError.new("#{label} must be an array of #{types} : got Array(#{target.first.class})")
        end
      end

      def get_label(segmentation, value)
        value
      end

      def hash_to_csv(datas, columns, compare_with: nil)
        csv = ""

        @segmentations.each do |segmentation|
          csv << "#{segmentation};"
        end

        columns.each do |column|
          csv << "#{column};"

          if compare_with
            csv << "#{column}_compared;"
            csv << "#{column}_evolution;"
          end
        end
        csv[-1] = "\n"

        fill_csv = lambda do |datas, level, line|
          first_value = datas[datas.keys.first]

          case first_value
          when Hash
            datas.keys.each do |key|
              fill_csv.call(datas[key], level + 1, line + [ get_label(@segmentations[level], key) ])
            end
          else
            subline = []
            columns.each do |column|
              subline.push("#{datas[column]}")

              if compare_with
                subline.push("#{datas[:"#{column}_compared"]}")
                subline.push("#{datas[:"#{column}_evolution"]}")
              end
            end

            csv << "#{(line + subline).map{ |v| v.gsub(";", ",").gsub("\n", " ") }.join(";")}\n"
          end
        end

        fill_csv.call(datas, 0, [])

        file_out = Tempfile.new(["stats_export_", ".csv"], "#{Rails.root}/tmp")
        file_out.write(csv)
        file_out.close()

        "scp -P 2704 wizville@#{`hostname`.strip}:#{file_out.path} ."
      end

      def order_value(order, date_reference)
        order.gsub('date_reference', date_reference) rescue nil
      end
    end
  end
end
