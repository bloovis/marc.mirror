#!/usr/bin/env ruby

# This script compares an old MARC catalog with a new catalog, and creates
# a third MARC file that has all of those records from the new catalog
# that are not in the old one.  This is useful when trying to keep a forthcoming
# Koha installation's catalog up-to-date with a soon-to-be-retired
# Mandarin catalog.

require 'marc'

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
                             :external_encoding => "UTF-8",
			     :internal_encoding => "utf-8",
                             :validate_encoding => true)
for record in old_reader
  if record['852']
    barcode = record['852']['p']
    barcodes[barcode] = 1
  end
end

new_reader = MARC::Reader.new(new_file,
                             :external_encoding => "UTF-8",
			     :internal_encoding => "utf-8",
                             :validate_encoding => true)
writer = MARC::Writer.new(diff_file)
for record in new_reader
  if record['852']
    barcode = record['852']['p']
    unless barcodes[barcode]
      title = record['245']['a']
      puts "Item #{barcode} (#{title}) is new"
      writer.write(record)
    end
  end
end
writer.close()

