#!/usr/bin/env ruby

require 'marc'
require 'json'

def output_record(json, recno, writer)
  return if json == ''

  # Convert JSON back to hash.
  h = JSON.parse(json)

  # Convert hash back to a MARC record.
  record = MARC::Record.new_from_hash(h)

  # Write the MARC record to the output file.
  writer.write(record)
end

# Check arguments. First is input file.  Second is output file.
if ARGV.length < 2
   puts "usage: json2marc.rb json-input-file MARC-output-file"
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
json = ''
File.open(input_file) do |file|
  file.each do |line|
    if line =~ /------ Record (\d+) ------/
      new_recno = $1
      output_record(json, recno, writer)
      json = ''
      recno = new_recno
    else
      json += line
    end
  end
end
output_record(json, recno, writer)
writer.close
