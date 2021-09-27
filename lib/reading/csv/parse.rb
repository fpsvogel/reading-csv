# frozen_string_literal: true

require_relative "config"
require_relative "parse_regular_line"
require_relative "parse_compact_planned_line"

module Reading
  module Csv
    using Util::DeeperMerge

    # Parse is a function that parses CSV lines into item data (an array of hashes).
    class Parse
      attr_private :config, :cur_line

      def initialize(custom_config = {})
        unless config
          @config = Reading.config.deeper_merge(custom_config)
          if custom_config[:item] && custom_config[:item][:formats]
            config[:item][:formats] = custom_config[:item][:formats]
          end
          config.fetch(:csv).fetch(:columns)[:name] = true # Name column can't be disabled.
        end
        @cur_line = nil
      end

      # - returns a hash of item data in the same order as they arrive from feed.
      # - feed is anything with #each_line.
      # - if a block is given, parsing is stopped when it returns false.
      # - postprocess can be used to convert the data hashes into Items. this
      #   way Item can access the CSV source line, which is useful since Item
      #   does additional validation on the data, and in case of any errors it
      #   can pass along the source line to an error message.
      def call(feed = nil,
                path: nil,
                close_feed: true,
                selective: true,
                &postprocess)
        if feed.nil? && path.nil? && config.fetch(:csv).fetch(:path).nil?
          raise ArgumentError, "No file given to load."
        end
        feed ||= File.open(path || config.fetch(:csv).fetch(:path))
        items = []
        parse = ParseRegularLine.new(config)
        parse_compact_planned = ParseCompactPlannedLine.new(config)
        feed.each_line do |line|
          line.force_encoding(Encoding::UTF_8)
          @cur_line = line.strip
          case line_type
          when :blank, :comment
            next
          when :regular
            items += parse.call(cur_line, &postprocess)
          when :compact_planned_line
            items += parse_compact_planned.call(cur_line, &postprocess)
          end
          break if selective &&
                  !config.fetch(:csv).fetch(:selective_continue).call(items.last)
        end
        items
      rescue Errno::ENOENT
        raise FileError.new(path, label: "File not found!")
      rescue Errno::EISDIR
        raise FileError.new(path, label: "The reading list must be a file, not a directory!")
      ensure
        feed&.close if close_feed && feed.respond_to?(:close)
        # reset to pre-call state.
        initialize
      end

      private

      def line_type
        return :blank if cur_line.empty?
        if starts_with_comment_character?
          return :compact_planned_line if compact_planned_line?
          return :comment
        end
        :regular
      end

      def starts_with_comment_character?
        cur_line.start_with?(config.fetch(:csv).fetch(:comment_character)) ||
          cur_line.match?(/\A\s+#{config.fetch(:csv).fetch(:regex).fetch(:comment_escaped)}/)
      end

      def compact_planned_line?
        cur_line.match?(config.fetch(:csv).fetch(:regex).fetch(:compact_planned_line_start))
      end
    end
  end
end
