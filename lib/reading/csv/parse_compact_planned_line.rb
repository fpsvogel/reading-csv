# frozen_string_literal: true

require_relative "../util"
require_relative "../errors"
require_relative "parse_line"
require_relative "parse_attribute"

module Reading
  module Csv
    class Parse
      # using Util::Blank
      using Util::DeeperMerge

      # ParseCompactPlannedLine is a function that parses a line of compactly
      # listed planned items in a CSV reading list into an array of item data (hashes).
      class ParseCompactPlannedLine < ParseLine
        attr_private :genre, :line_without_genre

        private

        def before_parse
          list_start = line.match(config.fetch(:csv).fetch(:regex).fetch(:compact_planned_line_start))
          @genre = list_start[:genre]
          @genre = genre.downcase if genre == genre.upcase
          @line_without_genre = line.sub(list_start.to_s, "")
        end

        def multi_items_to_be_split_by_format_emojis
          line_without_genre
        end

        def item_data(name)
          match = name.match(config.fetch(:csv).fetch(:regex).fetch(:compact_planned_item))
          unless match
            raise InvalidItemError, "Invalid planned item"
          end
          author = ParseAuthor.new(config).call(match[:author_title])
          title = ParseTitle.new(config).call(match[:author_title])
          default = config.fetch(:item).fetch(:template)
          default.deeper_merge(
            author: author || default[:author],
            title: title,
            variants:  [{ format: format(match[:format_emoji]) || default[:variants].first[:format],
                          sources: sources(match[:sources]) || default[:variants].first[:sources] }],
            genres: [genre] || default[:genres]
          )
        end

        def format(format_emoji)
          config.fetch(:item).fetch(:formats).key(format_emoji)
        end

        def sources(sources_str)
          return nil if sources_str.nil?
          sources_str.split(config.fetch(:csv).fetch(:compact_planned_source_prefix))
                      .map { |source| source.sub(/\s*,\s*/, "") }
                      .map(&:strip)
                      .reject(&:empty?)
                      .map { |source| [source] }
        end
      end
    end
  end
end
