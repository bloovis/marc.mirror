#!/usr/bin/env ruby

# This script takes a Mandarin-generated "loan list by patron" PDF report,
# and outputs an equivalent "KOC" (Koha offline circulation) file
# for importing into Koha.

ARGV.each do |filename|
  IO.popen("pdftotext #{filename} -") do |f|
    patron = "XXX"
    barcode = nil
    borrowed = nil
    due = nil
    date = nil
    dates = []
    ms = 0
    puts "Version=1.0\tGenerator=pdf2koc.rb\tGeneratorVersion=0.1"
    f.each do |line|
      line.chomp!
      case line
      when /^([A-Z]\d\d\d\d)/
	patron = $1
	#puts "patron: #{patron}"
      when /(RPL\d\d\d\d\d)/
	barcode = $1
	#puts "barcode: #{barcode}"
	due = nil
	if dates.length > 0
	  if borrowed.nil?
	    borrowed = dates.shift
	    if dates.length > 0
	      due = dates.shift
	    end
          else
	    due = dates.shift
          end
	  unless due.nil?
	    puts "#{borrowed} 12:30:00 #{ms}\tissue\t#{patron}\t#{barcode}"
            ms += 1
	    barcode = nil
	    borrowed = nil
	  end
        end
      when /(\d\d)\/(\d\d)\/(\d\d\d\d)/
	date = $3 + '-' + $1 + '-' + $2
	#puts "date: #{date}"
	if barcode.nil?
	  dates << date
	elsif borrowed.nil?
	  borrowed = date
	else
	  due = date
          puts "#{borrowed} 12:30:00 #{ms}\tissue\t#{patron}\t#{barcode}"
	  ms += 1
	  barcode = nil
	  borrowed = nil
	end
      end
      if ms > 999
        ms = 0
      end
    end
  end
end
