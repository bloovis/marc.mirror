#!/usr/bin/env ruby

# Convert a MARC-8 encoded catalog to UTF-8.

require 'marc'

def print_record(record, recno)
  # Print out title and author.
  puts("------ Record #{recno} ------")
  puts("title: '#{record['245']['a']}'")
  return
  puts("subtitle: '#{record['245']['b']}'")
  if (record['100'])
    puts("author: '#{record['100']['a']}'")
  else
    puts("author: UNDEFINED!")
  end

  # Print out 852 holding fields.
  puts("branch (852): '#{record['852']['a']}'")
  puts("ILL branch (852): '#{record['852']['b']}'")
  puts("collection (852): '#{record['852']['h']}'")
  puts("author (852): '#{record['852']['i']}'")
  puts("prefix (852): '#{record['852']['k']}'")
  puts("price (852): '#{record['852']['9']}'")
  puts("barcode (852): '#{record['852']['p']}'")

  if (record['952'])
    puts("branch (952): '#{record['952']['a'] || "undefined"}'")
    puts("spine tag section (952): '#{record['952']['h'] || "undefined"}'")
    puts("spine tag author (952): '#{record['952']['i'] || "undefined"}'")
    puts("barcode (952): '#{record['952']['p'] || "undefined"}'")
  end
end

# Check arguments. First is input file.  Second is output file.
if ARGV.length != 2
   puts "usage: m8toutf8.rb infile outfile"
   exit 1
end
input_file = ARGV[0]
output_file = ARGV[1]
if File.exist?(output_file)
  puts "#{output_file} exists; will not overwrite."
  exit 1
end

reader = MARC::Reader.new(input_file,
                          :external_encoding => "MARC-8",
			  :internal_encoding => "utf-8",
                          :validate_encoding => true)
writer = MARC::Writer.new(output_file)

# Read records, convert to UTF-8, write to new file.
print_rec = 19719
recno = 0
for record in reader
  recno += 1
  if (recno == print_rec)
    print_record(record, recno)
  end
  writer.write(record)
end
puts("#{recno} records handled\n")
writer.close()
