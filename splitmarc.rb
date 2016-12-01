#!/usr/bin/env ruby

# Split a MARC-UTF-8 file into multiple pieces.

require 'marc'

# Check arguments. First is input file.  Second is output file.
if ARGV.length != 2
   puts "usage: splitmarc.rb infile size"
   puts "size: maximum number of records in each output file"
   puts "output files are 1.marc, 2.marc, etc."
   exit 1
end

input_file = ARGV[0]
if ARGV[1] =~ /^\d+$/
  size = ARGV[1].to_i
else
  puts "Size argument (#{ARGV[1]})	 is not a decimal number."
  exit 1
end


reader = MARC::Reader.new(input_file,
                          :external_encoding => "utf-8",
			  :internal_encoding => "utf-8",
                          :validate_encoding => true)

# Read records, write to new file, create a new file every size records.
recno = 0
fileno = 0
writer = nil
for record in reader
  if recno % size == 0
    if recno != 0
      writer.close()
    end
    fileno += 1
    filename = "#{fileno}.marc"
    puts "Creating #{filename}"
    writer = MARC::Writer.new(filename)
  end
  writer.write(record)
  recno += 1
end
writer.close()
puts("#{recno} records handled\n")

