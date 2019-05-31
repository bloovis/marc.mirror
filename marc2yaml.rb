#!/usr/bin/env ruby

require 'marc'
require 'psych'
require "#{File.dirname(__FILE__)}/locnames"

# Should be at least one input file argument.
if ARGV.length < 1
   puts "usage: marc2yaml.rb [-h] MARCfile..."
   exit 1
end

human = false
nopts = 0
ARGV.each do |arg|
  if arg == '-h'
    human = true
    nopts += 1
  else
    break
  end
end
ARGV.shift(nopts)

converter = LocNameConverter.new

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

    # Convert field numbers to human-friendly names
    if human
      new_hash = {}
      h.each do |k, v|
	#puts "hash key: #{k}, value class is #{v.class}"
	if k == "fields"
	  fields = []
	  v.each do |f|
	    # puts "  field class is #{f.class}"
	    new_field = {}
	    f.each do |fk, fv|
	      #puts "  field #{fk}, value class is #{fv.class}"
	      name = converter.get_name(fk)
	      if name
		#puts"   (#{name})"
		new_field[name] = fv
	      else
		new_field[fk] = fv
	      end
	      fields << new_field
	    end
	  end
	  new_hash["fields"] = fields
	else
	  new_hash[k] = v
	end
      end
      y = Psych.dump(new_hash)
    else
      y = Psych.dump(h)
    end
    # Convert hash to yaml
    puts y
  end
end
