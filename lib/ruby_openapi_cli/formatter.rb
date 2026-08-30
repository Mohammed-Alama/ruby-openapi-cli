require 'json'
require 'yaml'

module RubyOpenapiCli
  class Formatter
    FORMATS = %i[json yaml table].freeze

    def render(body, format)
      case format.to_sym
      when :yaml
        YAML.dump(parse(body))
      when :table
        render_table(parse(body))
      else
        JSON.pretty_generate(parse(body))
      end
    end

    def valid_format?(format)
      FORMATS.include?(format.to_sym)
    end

    private

    def parse(body)
      JSON.parse(body)
    rescue JSON::ParserError
      body
    end

    def render_table(data)
      rows = if data.is_a?(Hash) && data['books'].is_a?(Array)
               data['books']
             elsif data.is_a?(Array)
               data
             else
               return JSON.pretty_generate(data)
             end
      return JSON.pretty_generate(rows) unless rows.first.is_a?(Hash)

      headers = rows.flat_map(&:keys).uniq
      header_row = headers.join("\t")
      body_rows = rows.map { |row| headers.map { |h| row[h].to_s }.join("\t") }
      ([header_row] + body_rows).join("\n")
    end
  end
end
