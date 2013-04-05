module LaterDude
  module CalendarHelper
    def calendar_for(year, month, options={}, &block)
      Calendar.new(year, month, options, &block).to_html
    end

    def calendar_index_for(year, month, options={}, &block)
      Calendar.new(year, month, options, &block).index_days
    end
  end
end
