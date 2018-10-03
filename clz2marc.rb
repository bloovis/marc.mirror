#!/usr/bin/env ruby

# This script converts a CSV file containing a dump
# of a book catalog from collectorz.com to a MARC
# catalog that can be imported into Koha.

require 'csv'
require 'marc'
require 'zoom'


# Attempt to fetch a MARC record for a given ISBN from a
# Z39.50 server.  If found, return it as a MARC::Record object;
# otherwise return nil.

def get_z3950(isbn)
  servers = [
    [ 'lx2.loc.gov',		   210,	'LCDB' ],
    [ 'catalog.nypl.org',	   210,	'INNOPAC' ],
    [ 'catalog.dallaslibrary.org', 210,	'PAC' ]
  ]

  servers.each do |rec|
    host = rec[0]
    port = rec[1]
    db = rec[2]

    begin
      ZOOM::Connection.open(host, port) do |conn|
	conn.database_name = db
	conn.preferred_record_syntax = 'USMARC'
	rset = conn.search("@attr 1=7 #{isbn}")
	if rset[0]
	  puts "ISBN #{isbn} found at #{host}"
	  return MARC::Record.new_from_marc(rset[0].raw)
	else
	  puts "ISBN #{isbn} not found at #{host}"
	end
      end
    rescue => exc
      puts "Exception trying to search #{host}: #{exc}"
    end
  end
  return nil
end

dryrun = false		# Can be set to true by -n option
overwrite = false	# Can be set to true by -o option
use_z3950 = false	# Can be set to true by -z option

nopts = 0
ARGV.each do |arg|
  if arg == '-n'
    dryrun = true
    nopts += 1
  elsif arg == '-o'
    overwrite = true
    nopts += 1
  elsif arg == '-z'
    use_z3950 = true
    nopts += 1
  else
    break
  end
end
ARGV.shift(nopts)

# Check arguments. First is input file.  Second is output file.
if ARGV.length < 2
   puts "usage: clz2marc.rb [-n] [-o] inputfile.csv outputfile.marc"
   puts "  -n : don't write outfile, just print records from inputfile.csv"
   puts "  -o : overwrite existing output file"
   puts "  -z : use Z39.50 servers to fetch bib record"
   exit 1
end

input_file = ARGV[0]
output_file = ARGV[1]

unless dryrun
  if !overwrite && File.exist?(output_file)
    puts "#{output_file} exists; will not overwrite."
    exit 1
  end
  puts("Writing #{output_file} using utf-8 encoding")
  writer = MARC::Writer.new(output_file)
end

# Column names indexed by a symbol that will be used
# as an index to inds.

columns = {
  author:	"Author",
  title:	"Title",
  publisher:	"Publisher",
  pubdate:	"Publication Date",
  date:		"Added Date",
  dewey:	"Dewey",
  genre:	"Genre",
  lcclass:	"LC Classification",
  lccontrol:	"LC Control No.",
  subject:	"Subject",
  dimensions:	"Dimensions",
  format:	"Format",
  isbn:		"ISBN",
  pages:	"Pages",
  language:	"Language",
  subtitle:	"Sub Title",
  location:	"Location",
  purchdate:	"Purchase Date",
  price:	"Purchase Price",
  index:	"Index"		# Only used to generate fake barcode for testing
}

# Indices into a data row, indexed by column symbol.
# For example, to get the index for the dewey number,
# use inds[:dewey].  Then, to fetch the dewew number
# for a row, use row[inds[:dewey]].

inds = {}

# Map of location code to collections.
# Collections are A (adult), YA (young adult) and J (children).
# This library used location strings like this:
#   YA = Young Adult Fiction
# where the word to the left of the = appears to be
# a location code, and the words to the right appear
# to be a verbose description. Unfortunately, this library
# used "P" as the location code for both poetry and picture
# books, so the code below will use "PIC"
# for picture books.

locs = {
  'AB'  => 'A',		# Audio Books
  'BB'  => 'J',		# Board Book
  'B'   => 'A',		# Biography & Memior
  'E'   => 'J',		# New Readers
  'F'   => 'A',		# Adult Fiction
  'JF'  => 'J',		# Juvenile Fiction
  'JNF' => 'J',		# Jr & YA NON Fiction
  'LP'  => 'A',		# Large Print
  'NF'  => 'A',		# Adult NON Fiction
#  'P'   => 'J',		# Picture Books
  'P'   => 'A',		# Poetry
  'YA'  => 'YA'		# Young Adult Fiction
}

first = true

CSV.foreach(input_file) do |row|
  if first
    columns.each do |key, value|
      ind = row.index(value)
      if ind
	inds[key] = ind
      else
	puts "#{value} not seen in first row"
	exit 1
      end
    end
    first = false
  else
    isbn = row[inds[:isbn]]
    if dryrun
      puts "ISBN: #{isbn} Title: #{row[inds[:title]]} Subtitle: #{row[inds[:subtitle]]} #Author: #{row[inds[:author]]}"
    else
      # Try to fetch a MARC record from a Z39.50 server.
      # If not found, create one from scratch, filling
      # in as much as we can from the Collectorz info.
      record = nil
      if isbn =~ /^\d+$/ && use_z3950
	record = get_z3950(isbn)
      end
      unless record
        record = MARC::Record.new

	# IBSN
	record.append(MARC::DataField.new(
	  '20',' ',' ',
	  ['a', isbn]))

	# Author
	record.append(MARC::DataField.new(
	  '100','0',' ',
	  ['a', row[inds[:author]]]))

	# Title/Subtitle
	title = row[inds[:title]]
	record.append(MARC::DataField.new(
	  '245','0','0',
	  ['a', title],
	  ['b', row[inds[:subtitle]]]))

        # Library of Congress classification
	lcclass = row[inds[:lcclass]]
	classno, cutters = lcclass.split(' ', 2)
	record.append(MARC::DataField.new(
	  '50','0','0',
	  ['a', classno],
	  ['b', cutters]))

	# Library of Congress control number
	lcno = row[inds[:lccontrol]]
	record.append(MARC::DataField.new(
	  '10',' ',' ',
	  ['a', lcno]))

	# Pages, format, dimensions
	pages = row[inds[:pages]]
	format = row[inds[:format]]
	dimensions = row[inds[:dimensions]]
	record.append(MARC::DataField.new(
	  '300',' ',' ',
	  ['a', "#{pages} p." ],
	  ['b', format ],
	  ['c', dimensions]))

	# Publisher and publication date
	publisher = row[inds[:publisher]]
	pubdate = row[inds[:pubdate]]
	record.append(MARC::DataField.new(
	  '260',' ',' ',
	  ['b', publisher],
	  ['c', pubdate]))

      end

      # Determine Koha holding information.

      # Convert date from Mon DD, YYYY to YYYY-MM-DD
      if row[inds[:date]] =~ /^(\w\w\w) (\d\d), (\d\d\d\d)$/
        month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
	         'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'].index($1) + 1
	day = $2
	year = $3
	datestr = year + '-' + sprintf("%02d", month) + '-' + day
      end

      # The locations look like: JF = Juvenile Fiction
      # Use the first word as an index to the locs hash,
      # which gets us the collection code.
      loc = row[inds[:location]]
      if loc =~ /^(\w+) (.*)/
	location = $1
	remainder = $2
	collection = locs[location]
	unless collection
	  puts "Unrecognized location #{location} for #{title}"
        end
	# Special case for "P", which is used for Picture Books and Poetry.
	if location == 'P'
	  if remainder =~ /Picture/
	    location = 'PIC'
	    collection = 'J'
	  end
	end
      else
	puts "Invalid location #{location} for #{title}"
      end

      # Append Koha holding information.

      record.append(MARC::DataField.new(
	'952', ' ',  ' ',
	['8', collection],
	['a', 'RCML'],
	['b', 'RCML'],
        ['c', location],
	['d', datestr],
	['o', row[inds[:dewey]]],	# have to figure out correct value for fiction, kids, etc.
	['p', row[inds[:index]]],	# fake barcode -- to be corrected at 1st checkout
	['y', 'BK']))			# assume item type is book -- how are DVDs cataloged?
      writer.write(record)
    end
  end
end

unless dryrun
  writer.close()
end
