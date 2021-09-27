# frozen_string_literal: true

require_relative "../util"
require_relative "../errors"

module Reading
  module Csv
    class Parse
      class ParseLine
        # using Util::Blank

        class ParseVariants < ParseAttribute
          def call(name, columns)
            default = config.fetch(:item).fetch(:template).fetch(:variants).first
            format_in_name = format(name)
            length_in_length = length(columns[:length])
            extra_info_in_name = extra_info(name).presence
            sources_str = columns[:sources]&.presence || " "
            separator = if sources_str.match(config.fetch(:csv).fetch(:regex).fetch(:formats))
                          config.fetch(:csv).fetch(:regex).fetch(:formats_split)
                        else
                          config.fetch(:csv).fetch(:long_separator)
                        end
            sources_str.split(separator).map do |variant_with_extra_info|
              variant = variant_with_extra_info.split(config.fetch(:csv).fetch(:long_separator)).first
              { format: format(variant) || format_in_name    || default[:format],
                sources: sources(variant)                    || default[:sources],
                isbn: isbn(variant)                          || default[:isbn],
                length: length(variant, in_variant: true) ||
                                            length_in_length || default[:length],
                extra_info: extra_info(variant_with_extra_info).presence ||
                                          extra_info_in_name || default[:extra_info] }
            end
            .presence || [default.dup]
          end

          def format(str)
            emoji = str.match(/^#{config.fetch(:csv).fetch(:regex).fetch(:formats)}/).to_s
            config.fetch(:item).fetch(:formats).key(emoji)
          end

          def isbn(str)
            isbns = str.scan(config.fetch(:csv).fetch(:regex).fetch(:isbn))
            if isbns.count > 1
              raise InvalidItemError, "Only one ISBN/ASIN is allowed per item variant"
            end
            isbns[0]&.to_s
          end

          def sources(str)
            (sources_urls(str) + sources_names(str)
              .map { |name| [name]}).reject(&:empty?).presence
          end

          def sources_urls(str)
            str
              .scan(config.fetch(:csv).fetch(:regex).fetch(:sources))
              .map(&:compact)
              .reject do |source|
                source.first.match?(config.fetch(:csv).fetch(:regex).fetch(:isbn))
              end
          end

          def sources_names(str)
            sources_with_commas_around_length(str)
              .gsub(config.fetch(:csv).fetch(:regex).fetch(:sources), config.fetch(:csv).fetch(:separator))
              .split(config.fetch(:csv).fetch(:separator))
              .reject do |name|
                name.match?(config.fetch(:csv).fetch(:regex).fetch(:time_length)) ||
                  name.match?(config.fetch(:csv).fetch(:regex).fetch(:pages_length_in_variant))
              end
              .map { |name| name.sub(/\A\s*#{config.fetch(:csv).fetch(:regex).fetch(:formats)}\s*/, "") }
              .map(&:strip)
              .reject(&:empty?)
          end

          def sources_with_commas_around_length(str)
            str.sub(config.fetch(:csv).fetch(:regex).fetch(:time_length), ", \\1, ")
               .sub(config.fetch(:csv).fetch(:regex).fetch(:pages_length_in_variant), ", \\1, ")
          end

          def length(str, in_variant: false)
            return nil if str.nil?
            len = str.strip
            time_length = len.match(config.fetch(:csv).fetch(:regex).fetch(:time_length))&.captures&.first
            return time_length unless time_length.nil?
            pages_length_regex =
              if in_variant
                config.fetch(:csv).fetch(:regex).fetch(:pages_length_in_variant)
              else
                config.fetch(:csv).fetch(:regex).fetch(:pages_length)
              end
            len.match(pages_length_regex)&.captures&.first&.to_i
          end

          def extra_info(str)
            separated = str.split(config.fetch(:csv).fetch(:long_separator))
            separated.delete_at(0) # everything before the extra info.
            separated.reject do |str|
              str.start_with?("#{config.fetch(:csv).fetch(:series_prefix)} ") ||
                str.match(config.fetch(:csv).fetch(:regex).fetch(:series_volume))
            end
          end
        end
      end
    end
  end
end