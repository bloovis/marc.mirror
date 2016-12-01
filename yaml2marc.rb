#!/usr/bin/env ruby

require 'marc'
require 'psych'

def output_record(yaml, recno, writer)
  return if yaml == ''

  # Convert yaml back to hash.
  h = Psych.load(yaml)

  # Convert hash back to a MARC record.
  record = MARC::Record.new_from_hash(h)

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
File.open(input_file) do |file|
  file.each do |line|
    if line =~ /------ Record (\d+) ------/
      new_recno = $1
      output_record(yaml, recno, writer)
      yaml = ''
      recno = new_recno
    else
      yaml += line
    end
  end
end
output_record(yaml, recno, writer)
writer.close
