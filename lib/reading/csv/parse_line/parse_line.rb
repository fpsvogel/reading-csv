require_relative "../../errors"

module Reading
  module Csv
    class Parse
      # ParseLine is a base class that holds common behaviors.
      class ParseLine
        def initialize(merged_config)
          @line = nil # For why line needs to be an instance var, see subclasses.
          @config ||= merged_config
          after_initialize
        end

        def call(line, &postprocess)
          @line = line
          before_parse
          titles = []

          items = split_by_format_emojis.map { |name|
            data = item_data(name).then { |data| without_blank_hashes(data) }
            if titles.include?(data[:title])
              raise InvalidItemError, "A title must not appear more than once in the list"
            end
            titles << data[:title]

            if block_given?
              postprocess.call(data)
            else
              data
            end
          }.compact

          items

        rescue InvalidItemError, StandardError => e
          # TODO instead of rescuing StandardError here, test missing
          # initial/middle columns in ParseRegularLine#set_columns, and raise
          # appropriate errors if possible.
          unless e.is_a? InvalidItemError
            if @config.fetch(:errors).fetch(:catch_all_errors)
              e = InvalidItemError.new("A line could not be parsed. Check this line")
            else
              raise e
            end
          end

          e.handle(source: @line, config: @config)
          []
        ensure
          # Reset to pre-call state.
          initialize(@config)
        end

        private

        def split_by_format_emojis
          multi_items_to_be_split_by_format_emojis
            .split(@config.fetch(:csv).fetch(:regex).fetch(:formats_split))
            .tap { |names|
              names.first.sub!(@config.fetch(:csv).fetch(:regex).fetch(:dnf), "")
              names.first.sub!(@config.fetch(:csv).fetch(:regex).fetch(:progress), "")
            }
            .map { |name| name.strip.sub(/\s*[,;]\z/, "") }
            .partition { |name| name.match?(/\A#{@config.fetch(:csv).fetch(:regex).fetch(:formats)}/) }
            .reject(&:empty?)
            .first
        end

        # Removes blank arrays of hashes from the given item hash, e.g. series,
        # variants, variants[:sources], and experiences in the template in config.rb.
        # If no parsed data has been added to the template values for these,
        # they are considered blank, and are replaced with an empty array to
        # clarify their blankness.
        def without_blank_hashes(data_hash, template: @config.fetch(:item).fetch(:template))
          data_hash.map { |key, val|
            if is_array_of_hashes?(val)
              if is_blank_like_template?(val, template.fetch(key))
                [key, []]
              else
                [key, val.map { without_blank_hashes(_1, template: template.fetch(key).first) }]
              end
            else
              [key, val]
            end
          }.to_h
        end

        def is_array_of_hashes?(val)
          val.is_a?(Array) && val.first.is_a?(Hash)
        end

        def is_blank_like_template?(val, template_val)
          val.length == 1 && val == template_val
        end

        # Hook, can be overridden.
        def after_initialize
        end

        # Hook, can be overridden.
        def before_parse
        end

        def multi_items_to_be_split_by_format_emojis
          raise NotImplementedError, "#{self.class} should have implemented #{__method__}"
        end

        def item_data(name)
          raise NotImplementedError, "#{self.class} should have implemented #{__method__}"
        end
      end
    end
  end
end