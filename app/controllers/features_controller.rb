require "gherkin"
require "gherkin/formatter/pretty_formatter"
require 'gherkin/formatter/ansi_escapes'
require 'gherkin/formatter/step_printer'
require 'gherkin/formatter/argument'
require 'gherkin/formatter/escaping'
require 'gherkin/formatter/model'
require 'gherkin/native'

class FeaturesController < ApplicationController
  unloadable

  before_filter :find_project, :authorize

  def view
    feature_paths = []
    @project.custom_field_values.each do |custom_value|
      if custom_value.custom_field.name == "gherkin_features"
        feature_paths = custom_value.value.split(",")
      end
    end

    io = StringIO.new
    formatter = Gherkin::Formatter::HtmlFormatter.new(io, true, false)
    parser = Gherkin::Parser::Parser.new(formatter, true, "root", false)
    output = ""

    feature_paths.each do |path|
      features = get_features(path)
      features.each do |feature|
        parser.parse(feature, File.new("/tmp/feature.feature"), 0)
      end
    end
    @output = io.string
    @features = formatter.features
    @tags = formatter.tags
  end 

  private

  def get_features(path)
      entries = @repository.entries(path, @rev)

      if entries.nil? 
        return []
      end

      features = []
      entries.each do |entry|
        subpath = entry.path.gsub('//', '/')
        if entry.is_dir?
          features = features + get_features(subpath)  
        elsif entry.path.ends_with?(".feature")
          features.push(@repository.scm.cat(subpath)) 
        end
      end
      return features
  end

  def find_project
      @project = Project.find(params[:project_id])
      @repository = @project.repository
      (render_404; return false) unless @repository
      @rev = params[:rev].blank? ? @repository.default_branch : params[:rev].to_s.strip
  end
end

module Gherkin
  module Formatter
    class HtmlFormatter
      native_impl('gherkin')

      include AnsiEscapes
      include Escaping

      def initialize(io, monochrome, executing)
        @io = io
        @step_printer = StepPrinter.new
        @monochrome = monochrome
        @executing = executing
        @background = nil
        @tag_statement = nil
        @steps = []
        @features = []
        @tags = Set.new
      end

      def features
        @features
      end

      def tags
        @tags
      end

      def uri(uri)
        @uri = uri
      end

      def feature(feature)
        print_comments(feature.comments, '')
        print_tags(feature.tags, '')
        slug = feature.name.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
        @io.puts "<h3 id=\"#{slug}\" name=\"#{slug}\">#{feature.keyword}: #{feature.name} [<a href=\"#top\">Top</a>]</h3>"
        print_description(feature.description, '  ', false)
        @features.push(feature.name)
      end

      def background(background)
        replay
        @statement = background
      end

      def scenario(scenario)
        replay
        @statement = scenario
      end

      def scenario_outline(scenario_outline)
        replay
        @statement = scenario_outline
      end
      
      def replay
        @io.write "<div style='margin-left: 10px;'>"
        print_statement
        print_steps
        @io.write "</div>"
      end
      
      def print_statement
        return if @statement.nil?
        calculate_location_indentations
        @io.puts
        print_comments(@statement.comments, '  ')
        print_tags(@statement.tags, '  ') if @statement.respond_to?(:tags) # Background doesn't
        @io.write "<strong><u>#{@statement.keyword}</u>: #{@statement.name}</strong> [<a href=\"#top\">Top</a>]"
        location = @executing ? "#{@uri}:#{@statement.line}" : nil
        @io.puts indented_location(location, true)
        print_description(@statement.description, '    ')
        @statement = nil
      end

      def print_steps
        @io.write "<ul>"
        while(@steps.any?)
          print_step('skipped', [], nil, true)
        end
        @io.write "</ul>"
      end

      def examples(examples)
        replay
        @io.puts
        print_comments(examples.comments, '    ')
        print_tags(examples.tags, '    ')
        @io.puts "    #{examples.keyword}: #{examples.name}"
        print_description(examples.description, '      ')
        table(examples.rows)
      end

      def step(step)
        @steps << step
      end

      def match(match)
        @match = match
        print_statement
        print_step('executing', @match.arguments, @match.location, false)
      end

      def result(result)
        @io.write(up(1))
        print_step(result.status, @match.arguments, @match.location, true)
      end

      def print_step(status, arguments, location, proceed)
        @io.write "<li>"
        step = proceed ? @steps.shift : @steps[0]
        
        text_format = format(status)
        arg_format = arg_format(status)
        
        print_comments(step.comments, '    ')
        @io.write('    ')
        @io.write(text_format.text(step.keyword))
        @step_printer.write_step(@io, text_format, arg_format, step.name, arguments)
        @io.puts(indented_location(location, proceed))
        
        doc_string(step.doc_string) if step.doc_string
        table(step.rows) if step.rows
        @io.write "</li>"
      end

      class MonochromeFormat
        def text(text)
          text
        end
      end

      class ColorFormat
        include AnsiEscapes
        
        def initialize(status)
          @status = status
        end

        def text(text)
          self.__send__(@status) + text + reset
        end
      end

      def arg_format(key)
        format("#{key}_arg")
      end

      def format(key)
        if @formats.nil?
          if @monochrome
            @formats = Hash.new(MonochromeFormat.new)
          else
            @formats = Hash.new do |formats, status|
              formats[status] = ColorFormat.new(status)
            end
          end
        end
        @formats[key]
      end

      def eof
        replay
        # NO-OP
      end

      def done
        # NO-OP
      end

      def table(rows)
        cell_lengths = rows.map do |row| 
          row.cells.map do |cell| 
            escape_cell(cell).unpack("U*").length
          end
        end
        max_lengths = cell_lengths.transpose.map { |col_lengths| col_lengths.max }.flatten

        rows.each_with_index do |row, i|
          row.comments.each do |comment|
            @io.puts "      #{comment.value}"
          end
          j = -1
          @io.puts '      | ' + row.cells.zip(max_lengths).map { |cell, max_length|
            j += 1
            color(cell, nil, j) + ' ' * (max_length - cell_lengths[i][j])
          }.join(' | ') + ' |'
        end
      end

    private

      def doc_string(doc_string)
        @io.puts "<pre style=\"padding:5px;overflow: auto;background-color:#f2f2f2;\">" + doc_string.content_type + "\n" + escape_triple_quotes(indent(doc_string.value, '      ')) + "</pre>"
      end

      def exception(exception)
        exception_text = "#{exception.message} (#{exception.class})\n#{(exception.backtrace || []).join("\n")}".gsub(/^/, '      ')
        @io.puts(failed(exception_text))
      end

      def color(cell, statuses, col)
        if statuses
          self.__send__(statuses[col], escape_cell(cell)) + reset
        else
          escape_cell(cell)
        end
      end

      if(RUBY_VERSION =~ /^1\.9/)
        START = /#{'^'.encode('UTF-8')}/
        TRIPLE_QUOTES = /#{'"""'.encode('UTF-8')}/
      else
        START = /^/
        TRIPLE_QUOTES = /"""/
      end

      def indent(string, indentation)
        string.gsub(START, indentation)
      end

      def escape_triple_quotes(s)
        s.gsub(TRIPLE_QUOTES, '\"\"\"')
        s = CGI.escapeHTML(s)
      end

      def print_tags(tags, indent)
        if tags.empty?
            return
        end
 
        @io.write("<p><strong>")
        tags.each do |tag|
            slug = tag.name.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
            @io.write("<span id=\"#{slug}\" name=\"#{slug}\">#{tag.name}</a> ");
            @tags.add(tag.name)
        end
        @io.write("</strong></p>")
      end

      def print_comments(comments, indent)
        @io.write(comments.empty? ? '' : '<pre>' + comments.map{|comment| comment.value}.join("\n#{indent}") + "</pre>\n")
      end

      def print_description(description, indent, newline=true)
        if description != ""
          @io.puts '<p>' + description + '</p>'
          @io.puts if newline
        end
      end

      def indented_location(location, proceed)
        indentation = proceed ? @indentations.shift : @indentations[0]
        location ? (' ' * indentation + ' ' + comments + "# #{location}" + reset) : ''
      end

      def calculate_location_indentations
        line_widths = ([@statement] + @steps).map {|step| (step.keyword+step.name).unpack("U*").length}
        max_line_width = line_widths.max
        @indentations = line_widths.map{|w| max_line_width - w}
      end
    end
  end
end

