#!/usr/bin/env ruby

# Convert a MARC-8 encoded Mandarin patron file to a Koha CSV
# patron import file.
#
# Most of the conversion involves examining the subfields of the MARC 100 field.
#
# The library branch code is hardcoded in the 'branch' variable below.  Change its
# value as needed for your library.

require 'marc'

branch = 'VSPS'

# Convert a Mandarin-generated MARC record to one
# suitable for importing into Koha.

def convert_record(record, recno, branch)
  # Extract first and last name.
  if record['100']
    firstname = record['100']['a'] || ''
    surname = record['100']['c'] || ''
  else
    warn("Record #{recno} missing MARC field 100: skipping.")
    return
  end
  if firstname == '' || surname == ''
    warn("Record #{recno} has empty firstname or surname: skipping.")
    return
  end

  # Extract address and phone info.
  if record['110']
    address = record['110']['a'] || ''
    city = record['110']['b'] || ''
    state = record['110']['c'] || ''
    zipcode = record['110']['e'] || ''
    phone = record['110']['k'] || ''
    email = record['110']['m'] || ''
  else
    warn("Record #{recno} (#{surname},#{firstname}) missing MARC field 110: using blank address.")
  end
  if record['852']
    cardnumber = record['852']['p'] || ''
  else
    warn("Record #{recno} missing MARC field 852 for barcode: skipping.")
    return
  end
  puts "\"#{surname}\",\"#{firstname}\",\"#{address}\",\"#{city}\",\"#{state}\"," +
       "\"#{zipcode}\",\"#{phone}\",\"#{email}\",\"#{cardnumber}\"," +
       "#{branch},PT"
end

# Check arguments. First is input file.
if ARGV.length != 1
   puts "usage: patroncsv.rb infile"
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
  convert_record(record, recno, branch)
end
