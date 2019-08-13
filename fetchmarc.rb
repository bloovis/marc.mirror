#!/usr/bin/env ruby

# This script attempts to fetch a MARC record from a Z39.50
# server, given an ISBN.  The list of Z39.50 servers is fixed;
# see @@servers below.

require 'zoom'
require 'marc'

verbose = false   	# Change to true print some debugging info
overwrite = false	# Can be set to true by -o option

class Fetcher

  @@servers = [
  #  [ 'z3950.loc.gov',	7090,	'Voyager' ],
  #  [ 'vokal.bywatersolutions.com', 9968, 'biblios' ],
    [ 'lx2.loc.gov',	210,	'LCDB' ],
    [ 'catalog.nypl.org', 210,	'INNOPAC' ],
    [ 'catalog.dallaslibrary.org', 210,	'PAC' ]
  ]

  def initialize(isbn, verbose=false)
    @verbose = verbose
    @isbn = isbn
  end

  def write_marc(output_file)
    @@servers.each do |rec|
      host = rec[0]
      port = rec[1]
      db = rec[2]

      begin
	ZOOM::Connection.open(host, port) do |conn|
	  conn.database_name = db
	  conn.preferred_record_syntax = 'USMARC'
	  rset = conn.search("@attr 1=7 #{@isbn}")
	  if rset[0]
	    puts "ISBN #{@isbn} found at #{host}:#{port}/#{db}:"
	    #puts rset[0].to_s
	    #puts "Raw record:"
	    #p rset[0].raw
	    record = MARC::Record.new_from_marc(rset[0].raw,
	      :external_encoding => 'utf-8',
	      :internal_encoding => 'utf-8')
	    if @verbose
	      puts "MARC record:"
	      puts record.to_s
	    end

	    puts "Writing record to #{output_file}"
            writer = MARC::Writer.new(output_file)
	    writer.write(record)
	    writer.close

	    return
	  else
	    puts "ISBN #{@isbn} not found at #{host}"
	  end
	end
      rescue => exc
	puts "Exception trying to search #{host}: #{exc}"
	exit 1
      end
    end
  end # write_marc

end # class Fetcher

nopts = 0
ARGV.each do |arg|
  if arg == '-o'
    overwrite = true
    nopts += 1
  elsif arg == '-v'
    verbose = true
    nopts += 1
  else
    break
  end
end
ARGV.shift(nopts)

# Check arguments. First is input file.  Second is output file.
if ARGV.length < 2
   puts "usage: fetchmarc.rb [-o|-v] MARC-output-file isbn"
   puts "  -o : overwrite existing output file"
   puts "  -v : print verbose debugging information"
   exit 1
end

output_file = ARGV[0]
isbn = ARGV[1]

if !overwrite && File.exist?(output_file)
  puts "#{output_file} exists; will not overwrite."
  exit 1
end

f = Fetcher.new(isbn, verbose)
f.write_marc(output_file)
