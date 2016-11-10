#!/usr/bin/env ruby

require 'marc'

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
                            #:external_encoding => "cp866",
                            :external_encoding => "UTF-8",
                            #:external_encoding => "MARC-8",
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
