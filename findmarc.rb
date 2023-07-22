#!/usr/bin/env ruby

# Search a MARC-UTF-8 file and extract one matching the specified barcode.

require 'marc'

# Check arguments. First is input file.  Second is barcode. Third is output file.
if ARGV.length != 3
   puts "usage: findmarc.rb infile.marc barcode outfile.marc"
   puts "Search infile.marc for the record with the specified barcode"
   puts "and write that record to outfile.marc"
   exit 1
end

input_file = ARGV[0]
barcode = ARGV[1]
output_file = ARGV[2]

# puts "Checking if #{output_file} exists"
if File.exist?(output_file)
  puts "#{output_file} exists; will not overwrite."
  exit 1
end

reader = MARC::Reader.new(input_file,
                          :external_encoding => "utf-8",
			  :internal_encoding => "utf-8",
                          :validate_encoding => true)

# Read records, write to new file, create a new file every size records.
found = false
for record in reader
  if record['952']['p'] == barcode
    puts "Creating #{output_file}"
    writer = MARC::Writer.new(output_file)
    writer.write(record)
    writer.close()
    found = true
    break
  end
end
print "record with barcode #{barcode} not found" unless found
