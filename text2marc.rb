#!/usr/bin/env ruby

require 'marc'
require 'psych'

def convert_fields(record, tag, rest)
  # puts "tag = #{tag}, rest = #{rest}"
  
  rest.gsub!(/\\/,' ')
  if tag == 'LDR'
    tag = '000'
  end
  if tag >= '000' && tag <= '009'
    puts("Control field #{tag}, content = '#{rest}'")
    field = MARC::ControlField.new(tag, rest)
  else
    ind1 = rest[0]
    ind2 = rest[1]
    rest = rest[2..-1]
    field = MARC::DataField.new(tag, ind1, ind2)
    puts("Normal field #{tag}, ind1 = #{ind1}, ind2 = #{ind2}, remainder = #{rest}")
    subfields = rest.split('$')
    subfields.each do |sf|
      if sf != ''
	type = sf[0]
	value = sf[1..-1]
	puts("  subfield #{type}, value = '#{value}'")
	subfield = MARC::Subfield.new(type, value)
	field.append(subfield)
      end
    end
  end
  record.append(field)
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

recno = 0
File.open(input_file) do |file|
  file.each do |line|
    if line =~ /^=(\d\d\d|LDR)\s*(.*)$/
      convert_fields(record, $1, $2)
    end
  end
end

# Write the MARC record to the output file.
writer.write(record)
writer.close
