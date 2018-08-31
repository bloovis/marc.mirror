#!/usr/bin/env ruby

# This script converts a CSV file containing a dump
# of a book catalog from collectorz.com to a MARC
# catalog that can be imported into Koha.

require 'csv'
require 'marc'

dryrun = false

nopts = 0
ARGV.each do |arg|
  if arg == '-n'
    dryrun = true
    nopts += 1
  else
    break
  end
end
ARGV.shift(nopts)

# Check arguments. First is input file.  Second is output file.
if ARGV.length < 2
   puts "usage: csv2marc.rb [-n] [-u] inputfile.csv outputfile.marc"
   puts "-n : don't write outfile, just print records from inputfile.csv"
   exit 1
end

input_file = ARGV[0]
output_file = ARGV[1]

unless dryrun
  if File.exist?(output_file)
    puts "#{output_file} exists; will not overwrite."
    exit 1
  end
  puts("Writing #{output_file} using utf-8 encoding")
  writer = MARC::Writer.new(output_file)
end

first = true
isbn = -1
title = -1
subtitle = -1
author = -1
date = -1
dewey = -1
price = -1
location = -1

CSV.foreach(input_file) do |row|
  if first
    isbn = row.index('ISBN')
    unless isbn
      puts "ISBN not seen in first row"
      exit 1
    end
    title = row.index('Title')
    unless title
      puts "Title not seen in first row"
      exit 1
    end
    subtitle = row.index('Sub Title')
    unless subtitle
      puts "Subtitle not seen in first row"
      exit 1
    end
    author = row.index('Author')
    unless author
      puts "Author not seen in first row"
      exit 1
    end
    date = row.index('Added Date')
    unless date
      puts "Added date not seen in first row"
      exit 1
    end
    dewey = row.index('Dewey')
    unless dewey
      puts "Dewey not seen in first row"
      exit 1
    end
    price = row.index('Purchase Price')
    unless price
      puts "Purchase Price not seen in first row"
      exit 1
    end
    location = row.index('Location')
    unless location
       puts "Location not seen in first row"
    end
    first = false
  else
    if dryrun
      puts "ISBN: #{row[isbn]} Title: #{row[title]} Subtitle: #Author: #{row[author]}"
    else
      # Write MARC record
      record = MARC::Record.new
      # IBSN
      record.append(MARC::DataField.new(
        '20','','',
	['a', row[isbn]]))
      # Author
      record.append(MARC::DataField.new(
        '100','0','',
	['a', row[author]]))
      # Title/Subtitle
      record.append(MARC::DataField.new(
        '245','0','0',
	['a', row[title]],
	['b', row[subtitle]]))
      # Koha holding information
      # Convert date from Mon DD, YYYY to YYYY-MM-DD
      if row[date] =~ /^(\w\w\w) (\d\d), (\d\d\d\d)$/
        month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
	         'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'].index($1) + 1
	day = $2
	year = $3
	datestr = year + '-' + sprintf("%02d", month) + '-' + day
      end
      record.append(MARC::DataField.new(
	'952', ' ',  ' ',
        ['c', row[location]],
	['d', datestr],
	['o', row[dewey]],
	['v', row[price]]))
      writer.write(record)
    end
  end
end

unless dryrun
  writer.close()
end
