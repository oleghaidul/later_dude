require 'action_view'
require 'action_view/helpers'
require 'action_view/helpers/capture_helper'
require 'action_view/helpers/tag_helper'
require 'action_view/helpers/url_helper'

begin
  require 'active_support/core_ext/date/acts_like'
  require 'active_support/core_ext/date_time/acts_like'
  require 'active_support/core_ext/time/acts_like'

  require 'active_support/core_ext/integer/time'
  require 'active_support/core_ext/numeric/time'
rescue LoadError
  # nothing
end

module LaterDude
  # TODO: Maybe make output prettier?
  class Calendar
    include ActionView::Helpers::CaptureHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::UrlHelper

    attr_accessor :output_buffer, :total_days

    def initialize(year, month, options={}, &block)
      @year, @month = year, month
      @options = options.symbolize_keys.reverse_merge(self.class.default_calendar_options)

      # next_month and previous_month take precedence over next_and_previous_month
      @options[:next_month]     ||= @options[:next_and_previous_month]
      @options[:previous_month] ||= @options[:next_and_previous_month]

      @days = Date.civil(@year, @month, 1)..Date.civil(@year, @month, -1)
      @block = block
      @periods = @options[:periods]
      @header_color = @options[:color] || '#D5EBDA'
    end

    def to_html
      content_tag(:div, :class => "calendar") do
        content_tag(:div, "#{show_month_names}".html_safe, :class => 'header', :style => "background-color:#{@header_color};") +
        content_tag(:div, "#{show_day_names}".html_safe, :class => 'day-headers') +
        content_tag(:div, show_days, :class => 'calendar-body')
      end
    end

    def index_days
      content_tag(:div, show_index_days, class: 'calendar-days')
    end

    private
    def show_days
      content_tag(:div, "#{show_previous_month}#{show_current_month}#{show_following_month}".html_safe)
    end

    def show_index_days
      content_tag(:div, "#{show_current_month_index}".html_safe)
    end

    def show_previous_month
      @total_days = (beginning_of_week(@days.first)..@days.first - 1).count || 0
      return if @days.first.wday == first_day_of_week # don't display anything if the first day is the first day of a week
      "".tap do |output|
        beginning_of_week(@days.first).upto(@days.first - 1) { |d| output << show_day(d) }
      end.html_safe
    end

    def show_current_month
      @total_days += @days.count
      "".tap do |output|
        @days.first.upto(@days.last) { |d| output << show_day(d) }
      end.html_safe
    end

    def show_following_month
      "".tap do |output|
        # diff = 42 - total_days - (@days.last + 1).upto(beginning_of_week(@days.last + 1.week) - 1).count
        (@days.last + 1).upto(beginning_of_week(@days.last + 1.week) - 1) { |d| output << show_day(d) }
      end.html_safe
    end

    def show_previous_month_index
      @total_days = (beginning_of_week(@days.first)..@days.first - 1).count || 0
      return if @days.first.wday == first_day_of_week # don't display anything if the first day is the first day of a week
      "".tap do |output|
        beginning_of_week(@days.first).upto(@days.first - 1) { |d| output << show_index_day(d) }
      end.html_safe
    end

    def show_current_month_index
      @days.count
      "".tap do |output|
        @days.first.upto(@days.last) { |d| output << show_index_day(d) }
      end.html_safe
    end

    def show_following_month_index
      "".tap do |output|
        # diff = 42 - total_days - (@days.last + 1).upto(beginning_of_week(@days.last + 1.week) - 1).count
        (@days.last + 1).upto(beginning_of_week(@days.last + 1.week) - 1) { |d| output << show_index_day(d) }
      end.html_safe
    end

    def show_day(day)
      hash_params = status(@periods, day.to_date) || {}
      hash_params.merge!(date: "#{day}")
      options = { :class => "day" }
      day.month != @days.first.month ? options[:class] << " blank" : options.merge!(data: hash_params)
      options[:class] << " today" if day.today?

      # block is only called for current month or if :yield_surrounding_days is set to true
      if @block && (@options[:yield_surrounding_days] || day.month == @days.first.month)
        content, options_from_block = Array(@block.call(day))

        # passing options is optional
        if options_from_block.is_a?(Hash)
          options[:class] << " #{options_from_block.delete(:class)}" if options_from_block[:class]
          options.merge!(options_from_block)
        end
      else
        content = day.day
      end
      content = '' if day.month != @days.first.month

      content = content_tag(:div, options) do
        content_tag(:span, content.to_s.html_safe) +
        tag("img", :src => "/assets/blank_image.gif")
      end

      # close table row at the end of a week and start a new one
      # opening and closing tag for the first and last week are included in #show_days
      # content << "</tr><tr>".html_safe if day < @days.last && day.wday == last_day_of_week
      content
    end

    def show_index_day(day)
      hash_params = status(@periods, day.to_date) || {}
      hash_params.merge!(date: "#{day}")
      options = { :class => "day" }
      day.month != @days.first.month ? options[:class] << " blank" : options.merge!(data: hash_params)
      options[:class] << " today" if day.today?

      # block is only called for current month or if :yield_surrounding_days is set to true
      if @block && (@options[:yield_surrounding_days] || day.month == @days.first.month)
        content, options_from_block = Array(@block.call(day))

        # passing options is optional
        if options_from_block.is_a?(Hash)
          options[:class] << " #{options_from_block.delete(:class)}" if options_from_block[:class]
          options.merge!(options_from_block)
        end
      else
        content = day.day if day.month == @days.first.month
      end
      # content = '' if day.month != @days.first.month

      content = content_tag(:td, options) do
        content_tag(:span, content.to_s.html_safe)
      end
    end

    def status(periods, day)
      if periods.select{|arr| arr.start_date == day.to_date}.any? && periods.select{|arr| arr.end_date == day.to_date}.any?
        start_period = periods.select{|arr| arr.start_date == day.to_date}.first
        end_period = periods.select{|arr| arr.end_date == day.to_date}.first
        {status: "bouth", period_id: [start_period.id, end_period.id], color: [start_period.color, end_period.color], price: [start_period.price, end_period.price]}
      elsif periods.select{|arr| arr.start_date == day.to_date}.any?
        period = periods.select{|arr| arr.start_date == day.to_date}.first
        {status: "start", period_id: period.id, color: period.color, price: period.price}
      elsif periods.select{|arr| arr.end_date == day.to_date}.any?
        period = periods.select{|arr| arr.end_date == day.to_date}.first
        {status: "end", period_id: period.id, color: period.color, price: period.price}
      elsif periods.select{|arr| arr.start_date <= day.to_date && arr.end_date >= day.to_date}.any?
        period = periods.select{|arr| arr.start_date <= day.to_date && arr.end_date >= day.to_date}.first
        {status: "between", period_id: period.id, color: period.color, price: period.price}
      else
        {status: "not_found"}
      end
    end

    def beginning_of_week(day)
      diff = day.wday - first_day_of_week
      diff += 7 if first_day_of_week > day.wday # hackish ;-)
      day - diff
    end

    def show_month_names
      return if @options[:hide_month_name]

      content_tag(:span, "#{previous_month}#{current_month}#{next_month}".html_safe)
    end

    # @options[:previous_month] can either be a single value or an array containing two values. For a single value, the
    # value can either be a strftime compatible string or a proc.
    # For an array, the first value is considered to be a strftime compatible string and the second is considered to be
    # a proc. If the second value is not a proc then it will be ignored.
    def previous_month
      return unless @options[:previous_month]

      show_month(@days.first - 1.month, @options[:previous_month], :class => "previous")
    end

    # see previous_month
    def next_month
      return unless @options[:next_month]

      show_month(@days.first + 1.month, @options[:next_month], :class => "next")
    end

    # see previous_month and next_month
    def current_month
      colspan = @options[:previous_month] || @options[:next_month] ? 3 : 7 # span across all 7 days if previous and next month aren't shown

      show_month(@days.first, @options[:current_month], :colspan => colspan, :class => "current")
    end

    def show_month(month, format, options={})
      options[:colspan] ||= 2

      content_tag(:th, :colspan => options[:colspan], :class => "#{options[:class]} #{Date::MONTHNAMES[month.month].downcase}") do
        if format.kind_of?(Array) && format.size == 2
          text = I18n.localize(month, :format => format.first.to_s).html_safe
          format.last.respond_to?(:call) ? link_to(text, format.last.call(month)) : text
        else
          format.respond_to?(:call) ? format.call(month) : I18n.localize(month, :format => format.to_s)
        end.html_safe
      end
    end

    def day_names
      @day_names ||= @options[:use_full_day_names] ? full_day_names : abbreviated_day_names
    end

    def full_day_names
      @full_day_names ||= I18n.translate(:'date.day_names')
    end

    def abbreviated_day_names
      @abbreviated_day_names ||= I18n.translate(:'date.abbr_day_names')
    end

    def show_day_names
      return if @options[:hide_day_names]
      apply_first_day_of_week(day_names).inject('') do |output, day|
        output << content_tag(:div, include_day_abbreviation(day), :class => 'day-header')
      end.html_safe
    end

    # => <abbr title="Sunday">Sun</abbr>
    def include_day_abbreviation(day)
      return day if @options[:use_full_day_names]

      content_tag(:span, day)
    end

    def apply_first_day_of_week(day_names)
      names = day_names.dup
      first_day_of_week.times { names.push(names.shift) }
      names
    end

    def first_day_of_week
      @options[:first_day_of_week]
    end

    def last_day_of_week
      @options[:first_day_of_week] > 0 ? @options[:first_day_of_week] - 1 : 6
    end

    class << self
      def weekend?(day)
        [0,6].include?(day.wday) # 0 = Sunday, 6 = Saturday
      end

      def default_calendar_options
        {
          :calendar_class => "calendar",
          :first_day_of_week => I18n.translate(:'date.first_day_of_week', :default => "0").to_i,
          :hide_day_names => false,
          :hide_month_name => false,
          :use_full_day_names => false,
          :current_month => I18n.translate(:'date.formats.calendar_header', :default => "%B"),
          :next_month => false,
          :previous_month => false,
          :next_and_previous_month => false,
          :yield_surrounding_days => false
        }
      end
    end
  end
end

