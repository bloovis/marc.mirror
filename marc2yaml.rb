#!/usr/bin/env ruby

require 'marc'
require 'psych'

# Should be at least one input file argument.
if ARGV.length < 1
   puts "usage: marc2yaml.rb MARCfile..."
   exit 1
end

ARGV.each do |filename|
  reader = MARC::Reader.new(filename,
                            :external_encoding => "UTF-8",
			    :internal_encoding => "utf-8",
                            :validate_encoding => true)
  recno = 0
  reader.each do |record|
    recno += 1
    puts("------ Record #{recno} ------")
    # Convert MARC record to hash
    h = record.to_hash
    # Convert hash to yaml
    y = Psych.dump(h)
    puts y
  end
end
