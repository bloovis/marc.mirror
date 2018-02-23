#!/usr/bin/ruby

# This script reads a web page, saved locally from a "MARC Display" page
# in connexion.oclc.org.  When viewing that record, right click
# and select "Save Page As..." to save to a local file.  This will
# save a file called "OCLC\ Connexion.html" and several files in
# the subdirectory "OCLC Connexion_files".  In that subdirectory
# there should be a file called "catexprecord.html".  This is the file
# that you need to feed to this script.
#
# This script is complicated by a number of bugs in the Connexion web
# server:
#
# - The HTML is missing some fields that the Export tool would provide.
#   These include the 003 and 005 control fields, and the 035 data field.
#   These fields aren't strictly necessary, but the script fabricates
#   them for completeness.
#
# - The HTML is full of superfluous &nbsp; (UTF-8 c2 a0) non-breaking
#   space characters in the tag data.  These have to be stripped out
#   to prevent Koha from hanging while trying to display these fields.
#
# - Sometimes the HTML contains NUL (0) characters, and you only
#   discover this when Oga, the HTML parser used by this script,
#   generates an exception complaining about the problem.  You
#   have to edit the HTML file, remove the NUL, and try again.

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
    control_number = nil
    @document.css("tr").each do |row|
      puts "marc tag row (maybe?)" if verbose
      td = row.at_css("td.catexTag")
      if td
	tag_name = td.text.strip
	puts "  tag name: '#{tag_name}'" if verbose
	inds = row.at_css("td.catexInds").text.gsub(/&nbsp;/, '').gsub(/\n/, '')
	# row.css("td.catexInds").each do |ind|
	#  ind_text = ind.text.gsub(/&nbsp;/, '').gsub(/\n/, '')
	#  puts "  indicator: '#{ind_text}'" if verbose
	#  inds << ind_text
	# end
	puts "  indicators: '#{inds}'" if verbose
	tag_value = row.at_css("td.catexData").text.strip
	tag_value = tag_value.gsub(/\n/, '')
	# tag_value = tag_value.gsub(/\xc2\xa9/, 'copyright ')
	puts "  data: '#{tag_value}'" if verbose
	field = nil
	if tag_name >= '000' && tag_name <= '009'
	  # It's necessary to strip out the non-breaking spaces
	  # from the tag value; otherwise, Koha will hang trying
	  # to display the resulting record in the MARC
	  # import tool.
	  tag_value = tag_value.gsub(/\xc2\xa0/, ' ')
	  if tag_name == '008'
	    field = MARC::ControlField.new('003', 'OCoLC')
	    record.append(field)
	    now = DateTime.now
	    timestamp = now.strftime('%Y%m%d%H%M%S.0')
	    field = MARC::ControlField.new('005', timestamp)
	    record.append(field)
	  end
	  if tag_name != '000'
	    field = MARC::ControlField.new(tag_name, tag_value)
	    if tag_name == '001'
	      control_number = tag_value
	      puts "  Control number = #{tag_value}" if verbose
	    end
	  end
        else
	  if tag_name >= '043'
	    if control_number
	      field = MARC::DataField.new('035', ' ', ' ')
	      subfield = MARC::Subfield.new('a', '(OCoLC)' + control_number)
	      field.append(subfield)
	      record.append(field)
	      control_number = nil
	    end
	  end

	  # Need to split the data into subfields.  Example for 651:
	  #  Georgia (Republic)&nbsp;$x Description and travel.&nbsp;
	  # First subfield doesn't have a name; assumed to be $a.
	  field = MARC::DataField.new(tag_name, inds[0], inds[1])
	  subfields = tag_value.split(/\xc2\xa0\$/)
	  subfields.each_with_index do |subfield, i|
	    if i == 0
	      if subfield[0] == '$'
		subfield_name = subfield[1]
		subfield_value = subfield[3..-1]
	      else
		subfield_name = 'a'
		subfield_value = subfield
	      end
	    else
	      subfield_name = subfield[0]
	      subfield_value = subfield[2..-1]
	    end
	    subfield_value = subfield_value.gsub(/\xc2\xa0/, '')
	    puts "  subfield: name = '#{subfield_name}', value '#{subfield_value}'" if verbose
	    subfield = MARC::Subfield.new(subfield_name, subfield_value)
	    field.append(subfield)
	  end
	end
	if field
	  record.append(field)
	end
      end
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
  else
    break
  end
end
ARGV.shift(nopts)

# Check arguments. First is input file.  Second is output file.
if ARGV.length < 2
   puts "usage: oclc.rb [-o] input-url-or-file MARC-output-file"
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
