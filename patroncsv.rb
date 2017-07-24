#!/usr/bin/env ruby

# Convert a MARC-8 encoded Mandarin patron file to a Koha CSV
# patron import file.
#
# Most of the conversion involves examining the subfields of the MARC 100 field.
#
# The library branch code is hardcoded in the 'branch' variable below.  Change its
# value as needed for your library.
#
# The "gone no address" value is hardcoded in the 'gone_no_address' variable below.
# If 1, Koha will alert staff that the patron's address should be verified at checkout.

require 'marc'

branch = 'VSPS'
gone_no_address = 1
active_list = {}

# Read the file containing the list of active patrons' cardnumbers,
# return a hash of those cardnumbers.

def read_active_list(filename)
  hash = {}
  File.open(filename) do |file|
    file.each do |line|
      line.chomp!
      hash[line] = 0
    end
  end
  return hash
end

# Convert a Mandarin-generated MARC record to one
# suitable for importing into Koha.  Returns the cardnumber
# of the record if it was converted; otherwise nil.

def convert_record(record, recno, branch, gone, active_list)
  # Extract first and last name.
  if record['100']
    firstname = record['100']['a'] || ''
    surname = record['100']['c'] || ''
  else
    warn "Record #{recno} missing MARC field 100: skipping."
    return nil
  end
  if firstname == '' && surname == ''
    warn "Record #{recno} has empty firstname and surname: skipping."
    return nil
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
    warn "Record #{recno} (#{surname},#{firstname}) missing MARC field 110: using blank address."
  end

  # Extract barcode
  if record['852']
    cardnumber = record['852']['p'] || ''
  else
    warn "Record #{recno} missing MARC field 852 for barcode: skipping."
    return nil
  end
  if cardnumber !~ /^[A-Z]\d\d\d\d$/
    warn "Record #{recno} (#{firstname} #{surname}) has an invalid card number #{cardnumber}"
  end

  # If cardnumber is not in optional list of active patrons, skip it.
  if active_list.length != 0 && active_list[cardnumber].nil?
    warn "Skipping patron #{cardnumber} (#{firstname} #{surname}): not active."
    return nil
  end

  # Fix some cities.
  case city
  when 'ROCHESTER'
    city = 'Rochester'
  when 'GRANVILLE'
    city = 'Granville'
  when 'HANCOCK'
    city = 'Hancock'
  end

  # Output the record in CSV format.
  puts "\"#{surname}\",\"#{firstname}\",\"#{address}\",\"#{city}\",\"#{state}\"," +
       "\"#{zipcode}\",\"#{phone}\",\"#{email}\",\"#{cardnumber}\"," +
       "#{branch},PT,#{gone}"
  return cardnumber
end

# Check arguments. First is input MARC patron file.  Optional second is file
# containing list of cardnumbers of active patrons; if present, only
# patrons in this list will be converted.

if ARGV.length < 1
  puts "usage: patroncsv.rb infile [activefile]"
  exit 1
end
input_file = ARGV[0]
if ARGV.length == 2
  active_list = read_active_list(ARGV[1])
end

reader = MARC::Reader.new(input_file,
                          :external_encoding => "MARC-8",
			  :internal_encoding => "utf-8",
                          :validate_encoding => true)

# Read records, convert to UTF-8 and set Koha fields, write to new file.
recno = 0
puts "surname,firstname,address,city,state,zipcode,phone,email,cardnumber,branchcode,categorycode,gonenoaddress"
for record in reader
  recno += 1
  cardnumber = convert_record(record, recno, branch, gone_no_address, active_list)
  if cardnumber && active_list.length != 0
    active_list[cardnumber] = 1
  end
end

# Run through the list of active cardnumbers, and print those
# that were not seen in the MARC file.

active_list.each do |cardnumber, seen|
  if seen == 0
    warn "Patron #{cardnumber} in active list but not seen in patron MARC file"
  end
end
