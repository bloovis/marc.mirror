#!/usr/bin/env ruby

# This script compares an old Mandarin MARC catalog with a new catalog, and creates
# a third MARC file that has all of those records from the new catalog
# that are not in the old one, or records whose call number has changed.
# This is useful when trying to keep a forthcoming Koha installation's catalog
# in sync with a soon-to-be-retired Mandarin catalog.

require 'marc'

# Helper function to construct a call number from
# the Mandarin prefix, collection, and author.

def get_callno(record)
   prefix = record['852']['k']
   collection = record['852']['h']
   author = record['852']['i']
   return [prefix, collection, author].join(' ').strip
end

# Should be three filename arguments
if ARGV.length < 3
   puts "usage: diff.rb oldMARCfile newMARCfile diffMARCfile"
   puts "Writes all records in newMARCfile that are not in oldMARCfile"
   puts "to the new file diffMARCfile"
   exit 1
end

barcodes = {}

old_file = ARGV[0]
new_file = ARGV[1]
diff_file = ARGV[2]
if File.exist?(diff_file)
  puts "#{diff_file} exists; will not overwrite."
  exit 1
end

old_reader = MARC::Reader.new(old_file,
                             :external_encoding => "MARC-8",
			     :internal_encoding => "utf-8",
                             :validate_encoding => true)
for record in old_reader
  if record['852']
    barcode = record['852']['p']
    title = record['245']['a']
    callno = get_callno(record)
    if barcodes[barcode]
      puts "Multiple holdings for #{barcode}: #{title}, #{barcodes[barcode][0]}"
    end
    barcodes[barcode] = [title, callno]
  end
end

new_reader = MARC::Reader.new(new_file,
                             :external_encoding => "MARC-8",
			     :internal_encoding => "utf-8",
                             :validate_encoding => true)
puts "-----------------------"
puts "New or changed holdings"
puts "-----------------------"
writer = MARC::Writer.new(diff_file)
for record in new_reader
  if record['852']
    barcode = record['852']['p']
    title = record['245']['a']
    callno = get_callno(record)
    if barcodes[barcode]
      oldcallno = barcodes[barcode][1]
      if callno != oldcallno
        puts "#{barcode} #{title}: call number changed from #{oldcallno} to #{callno}"
        writer.write(record)
      end
      barcodes.delete(barcode)
    else
      puts "#{barcode} #{title}: new holding"
      writer.write(record)
    end
  end
end

puts "--------------"
puts "Deleted holdings"
puts "----------------"
barcodes.each do |barcode, info|
  title = info[0]
  callno = info[1]
  puts "#{barcode} #{title} #{callno}"
end

writer.close()

