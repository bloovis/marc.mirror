#!/usr/bin/ruby

# This script reads a web page, saved locally from a "MARC View" page
# in bpl.bibliocommons.com (Boston Public Library), and converts
# it to a MARC record.
#
# Despite the name of this script, it is not limited to BPL.  Any library OPAC
# using BiblioCommons could be used as a source; another example
# is the Chicago Public Library.  The full list of US libraries is here:
#
#  https://www.bibliocommons.com/about/libraries/united-states
#
# The use of this script is complicated by HTML syntax errors in the MARC 
# View.  To avoid these errors, middle-click on the "MARC Display" link
# when viewing the "Full Record" tab of a book detail page.  This opens
# a new browser tab containing just the MARC details.  Right click on this page,
# and select "Save Page As..." and then in the save dialog, select "Web Page, Complete".
# The resulting HTML should (one hopes) not have syntax errors, though
# if it does, the OGA parser will display the line number containing
# the error.

require 'set'
require 'oga'
require 'marc'
require 'date'

verbose = false   	# Change to true print some debugging info
overwrite = false	# Can be set to true by -o option

class Converter

private

  def dprint(str)
    if @debug
      puts str
    end
  end

  def dump_node(node, level)
    prefix = '  ' * level
    print "#{prefix}Level #{level}"
    if node.is_a?(Oga::XML::Text)
      puts ", Text = '#{node.text}'"
    elsif node.is_a?(Oga::XML::Element)
      puts ", Element name = #{node.name}"
      node.attributes.each do |attr|
	puts "#{prefix}    Attr #{attr.name} = #{attr.value}"
      end
    elsif
      puts ", unhandled class = #{node.class} node"
    end
    node.children.each {|child| dump_node(child, level + 1) }
  end

  def print_html_node(node)
    @close_tag = nil
    if node.is_a?(Oga::XML::Text)
      print node.text
    elsif node.is_a?(Oga::XML::Element)
      print "<#{node.name}"
      node.attributes.each do |attr|
	print " #{attr.name}=\"#{attr.value}\""
      end
      if node.self_closing?
	print "/>"
      else
	print ">"
	@close_tag = "</#{node.name}>"
      end
    end
    node.children.each {|child| print_html(child) }
    if @close_tag
      print @close_tag
    end
  end

public

  def initialize(filename, debug=false)
    @debug = debug
    @attr_stack = []
    @attrs = Set.new
    @text = nil

    if filename =~ /^https?:/
      handle = IO.popen(['wget', '-nv', '-O', '-', filename])
    else
      handle = File.open(filename)
    end
    parser = Oga::HTML::Parser.new(handle)
    @document = parser.parse
  end

  def dump
    puts "Dump:"
    dump_node(@document, 0)
  end

  def print_html
    dprint "HTML:"
    @attrs.clear
    print_html_node(@document)
  end

  def write_marc(output_file, verbose)
    writer = MARC::Writer.new(output_file)
    puts "MARC:" if verbose
    record = MARC::Record.new()
    @document.css("div#marc_details tr").each do |row|
      puts "marc tag row: " if verbose
      tag_name = row.at_css("td.marcTag").text.strip
      puts "  tag name: #{tag_name}" if verbose
      inds = row.at_css("td.marcIndicator").text.strip
      puts "  indicators: #{inds}" if verbose
      tag_value = row.at_css("td.marcTagData").text.strip
      puts "  tag value: #{tag_value}" if verbose
      if tag_name >= '000' && tag_name <= '009'
	field = MARC::ControlField.new(tag_name, tag_value)
      else
	field = MARC::DataField.new(tag_name, inds[0], inds[1])
	subfields = tag_value.split('$')
	subfields.each do |subfield|
	  if subfield != ''
	    subfield_name = subfield[0]
	    subfield_value = subfield[1..-1]
	    puts "  tag subfield name: #{subfield_name}, value: #{subfield_value}" if verbose
	    subfield = MARC::Subfield.new(subfield_name, subfield_value)
	    field.append(subfield)
	  end
	end
      end
      record.append(field)
    end
    writer.write(record)
    writer.close
  end

end

nopts = 0
ARGV.each do |arg|
  if arg == '-o'
    overwrite = true
    nopts += 1
  elsif arg == '-v'
    verbose = true
    nopts += 1
  else
    break
  end
end
ARGV.shift(nopts)

# Check arguments. First is input file.  Second is output file.
if ARGV.length < 2
   puts "usage: bpl.rb [-o] input-url-or-file MARC-output-file"
   puts "  -o : overwrite existing output file"
   exit 1
end

input_file = ARGV[0]
output_file = ARGV[1]

if !overwrite && File.exist?(output_file)
  puts "#{output_file} exists; will not overwrite."
  exit 1
end

c = Converter.new(input_file, verbose)
c.dump if verbose
c.write_marc(output_file, verbose)
