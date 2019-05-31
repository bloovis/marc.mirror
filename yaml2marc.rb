#!/usr/bin/env ruby

require 'marc'
require 'psych'
require "#{File.dirname(__FILE__)}/locnames"

def output_record(yaml, recno, writer, converter)
  return if yaml == ''

  # Convert yaml back to hash.
  h = Psych.load(yaml)

  # Convert human-friendly field names to LOC numbers
  new_hash = {}
  h.each do |k, v|
    #puts "hash key: #{k}, value class is #{v.class}"
    if k == "fields"
      fields = []
      v.each do |f|
	# puts "  field class is #{f.class}"
	new_field = {}
	f.each do |fk, fv|
	  #puts "  field #{fk}, value class is #{fv.class}"
	  number = converter.get_number(fk)
	  if number
	    #puts"   (#{name})"
	    new_field[number] = fv
	  else
	    new_field[fk] = fv
	  end
	  fields << new_field
	end
      end
      new_hash["fields"] = fields
    else
      new_hash[k] = v
    end
  end

  # Convert hash back to a MARC record.
  record = MARC::Record.new_from_hash(new_hash)

  # Write the MARC record to the output file.
  writer.write(record)
end

# Check arguments. First is input file.  Second is output file.
if ARGV.length < 2
   puts "usage: yaml2marc.rb yaml-input-file MARC-output-file"
   exit 1
end

input_file = ARGV[0]
output_file = ARGV[1]

if File.exist?(output_file)
  puts "#{output_file} exists; will not overwrite."
  exit 1
end
writer = MARC::Writer.new(output_file)

recno = 0
yaml = ''
converter = LocNameConverter.new
File.open(input_file) do |file|
  file.each do |line|
    if line =~ /------ Record (\d+) ------/
      new_recno = $1
      output_record(yaml, recno, writer, converter)
      yaml = ''
      recno = new_recno
    else
      yaml += line
    end
  end
end
output_record(yaml, recno, writer, converter)
writer.close
