#!/usr/bin/env ruby

require 'marc'

if ARGV.length < 1
   puts "usage: printraw.rb [-m] marcfile..."
   puts "-m : use MARC-8 encoding on marcfile instead of utf-8"
   exit 1
end

encoding = 'utf-8'
nopts = 0
ARGV.each do |arg|
  if arg == '-m'
    encoding = 'MARC-8'
    nopts += 1
  else
    break
  end
end
ARGV.shift(nopts)

ARGV.each do |filename|
  puts "Opening #{filename}"
    #   reader.each_raw do |raw|
    #     begin
    #       record = reader.decode(raw)
    #     rescue Encoding::InvalidByteSequenceError => e
    #       record = MARC::Reader.decode(raw, :external_encoding => "UTF-8",
    #                                         :invalid => :replace)
    #       warn e.message, record
    #     end
    #   end

  reader = MARC::Reader.new(filename,
                            :external_encoding => encoding,
			    :internal_encoding => "utf-8",
			    #:invalid => :replace, :replace => "???")
                            :validate_encoding => true)
  recno = 0
  reader.each_raw do |raw|
    recno += 1
    puts("------ Record #{recno} ------")
    record = reader.decode(raw)
    puts record
  end
  puts("#{recno} records handled\n")
end
