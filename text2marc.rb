#!/usr/bin/env ruby

require 'marc'
require 'psych'

def convert_record(record, line)
  # puts "tag = #{tag}, rest = #{rest}"
  
  if line !~ /^=(\d\d\d|LDR)\s*(.*)$/
    puts("Error: line not in correct format: #{line}")
    return
  end
  tag = $1
  rest = $2
  rest.gsub!(/\\/,' ')
  if tag == 'LDR'
    record.leader = rest
    return
  end
  if tag >= '000' && tag <= '009'
    #puts("Control field #{tag}, content = '#{rest}'")
    field = MARC::ControlField.new(tag, rest)
    if tag == '000'
      record.leader = field
    else
      record.append(field)
    end
  else
    ind1 = rest[0]
    ind2 = rest[1]
    rest = rest[2..-1]
    field = MARC::DataField.new(tag, ind1, ind2)
    #puts("Normal field #{tag}, ind1 = #{ind1}, ind2 = #{ind2}, remainder = #{rest}")
    subfields = rest.split('$')
    subfields.each do |sf|
      if sf != ''
	type = sf[0]
	value = sf[1..-1]
	#puts("  subfield #{type}, value = '#{value}'")
	subfield = MARC::Subfield.new(type, value)
	field.append(subfield)
      end
    end
    record.append(field)
  end
end

# Check arguments. First is input file.  Second is output file.
if ARGV.length < 2
   puts "usage: text2marc.rb text-input-file MARC-output-file"
   exit 1
end

input_file = ARGV[0]
output_file = ARGV[1]

if File.exist?(output_file)
  puts "#{output_file} exists; will not overwrite."
  exit 1
end
writer = MARC::Writer.new(output_file)
record = MARC::Record.new()

multiline = ''
File.open(input_file) do |file|
  file.each do |line|
    if line =~ /^=(\d\d\d|LDR)\s*(.*)$/
      if multiline != ''
	convert_record(record, multiline)
      end
      multiline = line.chomp
    else
      multiline << line.chomp
    end
  end
end
if multiline != ''
  convert_record(record, multiline)
end

# Write the MARC record to the output file.
writer.write(record)
writer.close
