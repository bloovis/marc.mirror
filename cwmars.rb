#!/usr/bin/ruby

require 'set'
require 'oga'

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

    handle = File.open(filename)
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

  def print_marc
    @tag_name = false
    @tag_data = false
    @subfield_name = false
    @subfield_data = false
    puts "MARC:"
    @document.css("tr.marc_tag_row").each do |row|
      puts "marc tag row: "
      tag_name = row.at_css("th.marc_tag_col").text.strip
      puts "  tag name: #{tag_name}"
      row.css("td.marc_tag_ind").each do |ind|
        ind_text = ind.text.gsub(/[. ]/, '')
	puts "  indicator: #{ind_text}"
      end
      subfields = row.at_css("td.marc_subfields")
      if subfields
	subfields.children.each do |child|
	  if child.is_a?(Oga::XML::Text)
	    puts "  tag subfield value: #{child.text}"
	  elsif child.is_a?(Oga::XML::Element) && child.name == 'span'
	    puts "  tag subfield name: #{child.text[-1]}"
	  end
	end
      end
    end
  end

end


verbose = false
ARGV.each do |filename|
  if filename == '-v'
    verbose = true
  else
    c = Converter.new(filename, verbose)
    c.dump if verbose
    c.print_marc
  end
end
