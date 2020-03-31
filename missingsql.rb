#!/usr/bin/env ruby

# This script reads a CSV file containing the output of the Koha
# inventory tool, and prints a list of SQL statements that can be used
# to mark the items as missing. 

require 'csv'
require 'marc'

printsql = true

nopts = 0
ARGV.each do |arg|
  if arg == '-n'
    printsql = false
    nopts += 1
  else
    break
  end
end
ARGV.shift(nopts)

if ARGV.length != 1
   puts "usage: missingsql.rb [options] inputfile.csv"
   puts "  -n : don't print SQL, just print barcodes"
   exit 1
end
input_file = ARGV[0]

# Create a CSV file object, telling it the column separator character.
f = File.open(input_file, "r")
unless f
  puts "Unable to open #{input_file}"
  exit 1
end

csv = CSV.new(f, col_sep: ',')
unless csv
  puts "Unable to create a CSV object for #{input_file}"
  exit 1
end

# Read the CSV file and output the SQL statements.
first = true
barcode_column = nil
csv.each do |row|
  # The first row contains column headers, from which we determine
  # the index of the Barcode field.
  if first
    barcode_column = row.index('Barcode')
    unless barcode_column
      puts "Barcode not seen in first row"
      exit 1
    end
    first = false
  else
    if printsql
      puts "update items set itemlost = 4 where barcode = '#{row[barcode_column]}';"
    else
      puts row[barcode_column]
    end
  end
end
