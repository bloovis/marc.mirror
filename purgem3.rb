#!/usr/bin/env ruby

# Remove Mandarin-specific fields (such as 852) from records in a MARC file.

require 'marc'

def copy_record(input_record, recno, writer)
  #puts("------ Record #{recno} ------")

  # Create an output record, which will contain everything
  # from the input record EXCEPT any 852 or 908 fields.
  record = MARC::Record.new

  # Copy the leader, which contains important information about
  # material type.
  record.leader = input_record.leader

  input_record.each do |field|
    unless ['852', '908'].index(field.tag)
      record.append(field)
    end
  end # each field

  # Write out the converted record.
  writer.write(record)
end

# Check arguments. First is input file.  Second is output file.
if ARGV.length < 2
   puts "usage: purgem3.rb infile outfile"
   puts "Purge all Mandarin M3 records from infile"
   exit 1
end

encoding = 'utf-8'

input_file = ARGV[0]
output_file = ARGV[1]

if File.exist?(output_file)
  puts "#{output_file} exists; will not overwrite."
  exit 1
end

puts("Reading #{input_file} using #{encoding} encoding")
reader = MARC::Reader.new(input_file,
                          :external_encoding => encoding,
			  :internal_encoding => "utf-8",
                          :validate_encoding => true)
puts("Writing #{output_file} using utf-8 encoding")
writer = MARC::Writer.new(output_file)

# Read records, remove M3-specific records, write to output file.
recno = 0
for record in reader
  recno += 1
  copy_record(record, recno, writer)
  #puts "processed record #{recno}"
end
puts("#{recno} records handled\n")
writer.close()
