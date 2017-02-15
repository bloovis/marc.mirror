#!/usr/bin/env ruby

puts "Version=1.0     Generator=pdf2koc.rb     GeneratorVersion=0.0"

ARGV.each do |filename|
  File.open(filename) do |f|
    patron = "MISSING"
    barcode = nil
    borrowed = nil
    due = nil
    date = nil
    dates = []
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
	    puts "#{borrowed} 12:30:00\tissue\t#{patron}\t#{barcode}"
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
          puts "#{borrowed} 12:30:00\tissue\t#{patron}\t#{barcode}"
	  barcode = nil
	  borrowed = nil
	end
      end
    end
  end
end
