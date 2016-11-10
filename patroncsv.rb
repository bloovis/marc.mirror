#!/usr/bin/env ruby

# Convert a MARC-8 encoded Mandarin patron file to a Koha CSV
# patron import file.
#
# Most of the conversion involves examining the subfields of the MARC 100 field.

require 'marc'

# Convert a Mandarin-generated MARC record to one
# suitable for importing into Koha.

def convert_record(record, recno)
  # Print first and last name
  if record['100']
    firstname = record['100']['a'] || ''
    surname = record['100']['c'] || ''
  else
    warn("Record #{recno} missing MARC field 100!")
    return
  end
  # 110    $a 40 Cannon Dr $b Rochester $c VT $e 05767 $k 967-8019 or 234 5505 
  if record['110']
    address = record['110']['a'] || ''
    city = record['110']['b'] || ''
    state = record['110']['c'] || ''
    zipcode = record['110']['e'] || ''
    phone = record['110']['k'] || ''
    email = record['110']['m'] || ''
  else
    warn("Record #{recno} missing MARC field 110!")
    return
  end
  if record['852']
    cardnumber = record['852']['p'] || ''
  else
    warn("Record #{recno} missing MARC field 852!")
    return
  end
  puts "\"#{surname}\",\"#{firstname}\",\"#{address}\",\"#{city}\",\"#{state}\"," +
       "\"#{zipcode}\",\"#{phone}\",\"#{email}\",\"#{cardnumber}\"," +
       "RPL,PT"
end

# Check arguments. First is input file.
if ARGV.length != 1
   puts "usage: patroncsv.rb infile"
   puts "-n : don't write outfile, just print records from infile"
   exit 1
end

input_file = ARGV[0]

reader = MARC::Reader.new(input_file,
                          :external_encoding => "MARC-8",
			  :internal_encoding => "utf-8",
                          :validate_encoding => true)

# Read records, convert to UTF-8 and set Koha fields, write to new file.
recno = 0
puts "surname,firstname,address,city,state,zipcode,phone,email,cardnumber,branchcode,categorycode"
for record in reader
  recno += 1
  convert_record(record, recno)
end
