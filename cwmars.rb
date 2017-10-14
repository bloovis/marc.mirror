#!/usr/bin/ruby

# This script reads a web page, either a local file or a URL, that should be
# the page that is produced when you click on "Bibliographic Record" link on
# an Evergreen (CWMARS) detail page for a book.  The resulting page should
# have the book's MARC information, from which the script generates an
# equivalent MARC record.  Here is an example of such a web page:
# http://catalog.cwmars.org/eg/opac/record/982124?qtype=author;_adv=1;detail_record_view=0;fi%3Asearch_format=book;locg=1;query=Lessing Doris 1919 2013;expand=marchtml#marchtml

require 'set'
require 'oga'
require 'marc'

verbose = false   # Change to true to get a dump of web page.

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
      handle = IO.popen(['wget', '-O', '-', filename])
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
    @document.css("tr.marc_tag_row").each do |row|
      puts "marc tag row: " if verbose
      tag_name = row.at_css("th.marc_tag_col").text.strip
      puts "  tag name: #{tag_name}" if verbose
      inds = []
      row.css("td.marc_tag_ind").each do |ind|
        ind_text = ind.text.gsub(/[.]/, '')
	puts "  indicator: #{ind_text}" if verbose
	inds << ind_text
      end
      if tag_name >= '000' && tag_name <= '009'
	tag_value = row.at_css("td.marc_tag_data").text.strip
	field = MARC::ControlField.new(tag_name, tag_value)
      else
	field = MARC::DataField.new(tag_name, inds[0], inds[1])
	subfields_row = row.at_css("td.marc_subfields")
	if subfields_row
	  subfield_name = nil
	  subfields_row.children.each do |child|
	    if child.is_a?(Oga::XML::Element) && child.name == 'span'
	      subfield_name = child.text[-1]
	    elsif child.is_a?(Oga::XML::Text)
	      subfield_value = child.text
	      puts "  tag subfield name: #{subfield_name}, value: #{subfield_value}" if verbose
	      subfield = MARC::Subfield.new(subfield_name, subfield_value)
	      field.append(subfield)
	    end
	  end
	end
      end
      record.append(field)
    end
    writer.write(record)
    writer.close
  end

end


# Check arguments. First is input file.  Second is output file.
if ARGV.length < 2
   puts "usage: cwmars.rb input-url-or-file MARC-output-file"
   exit 1
end

input_file = ARGV[0]
output_file = ARGV[1]

if File.exist?(output_file)
  puts "#{output_file} exists; will not overwrite."
  exit 1
end

c = Converter.new(input_file, verbose)
c.dump if verbose
c.write_marc(output_file, verbose)
