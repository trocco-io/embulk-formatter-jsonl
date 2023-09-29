require 'jrjackson'

module Embulk
  module Formatter

    class JsonlFormatterPlugin < FormatterPlugin
      Plugin.register_formatter("jsonl", self)

      VALID_ENCODINGS = %w(UTF-8 UTF-16LE UTF-32BE UTF-32LE UTF-32BE)
      NEWLINES = {
        'CRLF' => "\r\n",
        'LF' => "\n",
        'CR' => "\r",
        # following are not jsonl, but useful in some case
        'NUL' => "\0",
        'NO' => '',
      }

      def self.join_texts((*inits,last), opt = {})
      puts "Reach join_texts"

      delim = opt[:delimiter] || ', '
        last_delim = opt[:last_delimiter] || ' or '
        [inits.join(delim),last].join(last_delim)
      end

      def self.transaction(config, schema, &control)
        # configuration code:
        task = {
          'encoding' => config.param('encoding', :string, default: 'UTF-8'),
          'newline' => config.param('newline', :string, default: 'LF'),
          'date_format' => config.param('date_format', :string, default: nil),
          'timezone' => config.param('timezone', :string, default: nil ),
          'json_columns' => config.param("json_columns", :array,  default: [])
        }

        encoding = task['encoding'].upcase
        raise "encoding must be one of #{join_texts(VALID_ENCODINGS)}" unless VALID_ENCODINGS.include?(encoding)

        newline = task['newline'].upcase
        raise "newline must be one of #{join_texts(NEWLINES.keys)}" unless NEWLINES.has_key?(newline)

        puts "Reach transaction"

        yield(task)
      end

      def init
        # initialization code:
        @encoding = task['encoding'].upcase
        @newline = NEWLINES[task['newline'].upcase]
        @json_columns = task["json_columns"]

        # your data
        @current_file == nil
        @current_file_size = 0
        @opts = { :mode => :compat }
        date_format = task['date_format']
        timezone = task['timezone']
        @opts[:date_format] = date_format if date_format
        @opts[:timezone] = timezone if timezone

        puts "Reach init"
        puts file_output
        puts task
      end

      def close
        puts "Reach close"
      end

      def add(page)
        puts "add_first"
        puts page
        # output code:
        page.each do |record|
          if @current_file == nil || @current_file_size > 32*1024
            @current_file = file_output.next_file
            @current_file_size = 0
          end
          datum = {}
          @schema.each do |col|
            datum[col.name] = @json_columns.include?(col.name) ? JrJackson::Json.load(record[col.index]) : record[col.index]
          end

          data_str = "#{JrJackson::Json.dump(datum, @opts)}#{@newline}".encode(@encoding)
          @current_file.write data_str
          @current_file_size += data_str.bytesize
        end

        puts "add_last"
        puts @current_file
        puts page
      end

      def finish
        puts "finish"
        puts @current_file
        file_output.finish unless @current_file.nil?
      end
    end

  end
end
