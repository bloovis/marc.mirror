#!/usr/bin/env ruby

# Convert a MARC-8 encoded Mandarin catalog file to a Koha UTF-8
# catalog import file.
#
# Most of the conversion involves examining the subfields of the MARC 852 field
# (such as prefix, collection, and author), and determining the proper
# values for the 952 subfields required by Koha for importing
# (such as collection, location, call number, and item type). 
#
# The conversion rules in this code are probably not generally applicable; they
# are based on a particular library's requirements and quirks.

require 'marc'

# Remove 942 and 952 fields from a MARC record.
# It's done by making a new record because
#   record.fields.delete(field)
# doesn't seem to work.

def cleanup_record(record)
  if record['952'] || record['942']
    new_record = MARC::Record.new
    record.each do |field|
      if field.tag != '952' && field.tag != '942'
	 # puts "Appending field #{field.tag}"
	 new_record.append(field)
      else
	 # puts "Skipping field #{field.tag}"
      end
    end
    return new_record
  else
    return record
  end
end

# Convert a Mandarin-generated MARC record to one
# suitable for importing into Koha.

def convert_record(record, recno, dryrun, writer)
  # Print out title and author.
  if record['245']
    title = record['245']['a']
    subtitle = record['245']['b']
    if dryrun
      puts("------ Record #{recno} ------")
      puts("title: '#{title}'")
      puts("subtitle: '#{subtitle}'")
      if (record['100'])
	puts("author (100): '#{record['100']['a']}'")
      else
	puts("author (100): UNDEFINED!")
      end
    end
  else
    warn("Record #{recno} missing MARC field 245!")
    return
  end

  # Print out 852 holding fields.
  unless record['852']
    warn("Record #{recno} (#{title} #{subtitle}) missing MARC field 852!")
    return
  end

  # Get prefix.
  prefix = record['852']['k']
  if prefix
    prefix.strip!
  else
    prefix = ''
  end

  # Get collection.
  collection = record['852']['h']
  if collection
    collection.strip!
  else
    collection = ''
  end

  # Get author.
  author = record['852']['i']
  if author
    author.strip!
  else
    author = ''
  end

  # Regularize the price.
  price = record['852']['9'] || ''
  if price =~ /(\d+\.?\d+)/
    price = $1
  else
    price = ''
  end

  # Extract the barcode
  barcode = record['852']['p']

  # Print the Mandarin info
  if dryrun
    puts("branch (852): '#{record['852']['a']}'")
    puts("ILL branch (852): '#{record['852']['b']}'")
    puts("prefix (852): '#{prefix}'")
    puts("collection (852): '#{collection}'")
    puts("author (852): '#{author}'")
    puts("price (852): '#{price}'")
    puts("barcode (852): '#{barcode}'")
  end

  # Parse prefix.
  prefixes = prefix.split

  # Parse collection.
  collections = collection.split
  if collection =~ /(\d+[\d.\/]*)/
    dewey = $1
    if dryrun
      puts("Dewey: #{dewey}")
    end
  else
    dewey = nil
  end

  # Break down the various combinations of prefix(es), collection(s), and author
  # as found in the MARC 852 fields.  From these, determine Koha collection,
  # location, call number, and item type.
  kcoll = 'UNDEFINED'
  kloc  = 'UNDEFINED'
  kcall = 'UNDEFINED'
  kitem = 'UNDEFINED'

  if prefixes.index('J')
    # Kids' items
    kcoll = 'J'
    kloc = 'J'
    if collections.index('CD')
      # Kids' CDs
      kcall = "J CD #{author}"
      kitem = 'CD'
    elsif collections.index('DVD')
      kcall = "J DVD #{author}"
      kitem = 'DVD'
    elsif dewey
      # Kids' non-fiction
      kcall = "J #{dewey} #{author}"
      kitem = 'BK'
    elsif collections.index('FIC')
      # Kids' fiction
      kcall = "J FIC #{author}"
      kitem = 'BK'
    elsif collections.index('BIO')
      # Kids' biography
      kcall = "J BIO #{author}"
      kitem = 'BK'
    elsif collection =~ /CAS/
      # Kids' cassettes
      kcall = "J CAS #{author}"
      kitem = 'CAS'
    elsif collections.index('VID')
      # Kids' video cassettes
      kloc = 'CD'
      kcall = "J VID #{author}"
      kitem = 'VC'
    elsif collections.index('SPANISH')
      # Kids' Spanish books
      kcall = "J SPANISH #{author}"
      kitem = 'BK'
    end
  elsif prefixes.index('YA')
    # YA items
    kcoll = 'YA'
    if dewey
      if dewey =~ /741\.5/
        # YA graphic novel
	kloc = 'YA'
	kcall = "YA #{dewey} #{author}"
      else
	# Other YA non-fiction is stored with adult non-fiction,
	# but we keep the YA prefix on the call number.
	kloc = 'NFIC'
	kcall = "YA #{dewey} #{author}"
      end
      kitem = 'BK'
    elsif collections.index('FIC')
      # YA fiction
      kloc = 'YA'
      kcall = "YA FIC #{author}"
      kitem = 'BK'
    elsif collections.index('DVD')
      # YA DVD, fiction or non-fiction
      kloc = 'DVD'
      kcall = "DVD #{author}"
      kitem = 'DVD'
    elsif collections.index('BIO')
      # YA biography
      kloc = 'BIO'
      kcall = "BIO #{author}"
      kitem = 'BK'
    elsif collections.index('CD')
      # YA audiobooks
      kloc = 'CD'
      kcall = "CD #{author}"
      kitem = 'CD'
    elsif collections.index('PBK')
      # YA paperback
      kloc = 'PBK'
      kcall = "PBK #{author}"
      kitem = 'BK'
    end
  else
    # Adult items (and some kids' items that have no prefix)
    if dewey
      # Adult non-fiction
      kcoll = 'A'
      kloc = 'NFIC'
      kcall = "#{dewey} #{author}"
      kitem = 'BK'
    elsif collections.index('FIC')
      # Adult fiction
      if author > 'COBEN'
        # Downstairs
        kloc = 'FICD'
      else
        # Upstairs
        kloc = 'FICU'
      end
      kcoll = 'A'
      kcall = "FIC #{author}"
      kitem = 'BK'
    elsif collections.index('DVD')
      # Adult DVD, fiction or non-fiction
      kcoll = 'A'
      kloc = 'DVD'
      kcall = "DVD #{author}"
      kitem = 'DVD'
    elsif collections.index('BIO') || collections.index('Bio')
      # Adult biography
      kcoll = 'A'
      kloc = 'BIO'
      kcall = "BIO #{author}"
      kitem = 'BK'
    elsif collection =~ /CAS/
      # Adult cassette
      kcoll = 'A'
      kloc = 'CD'
      kcall = "CAS #{author}"
      kitem = 'CAS'
    elsif collection =~ /VID/
      # Adult video cassette
      kcoll = 'A'
      kloc = 'CD'
      kcall = "VID #{author}"
      kitem = 'VC'
    elsif collection =~ /pass/i
      # Park/museum pass
      kcoll = 'A'
      kloc = 'STAFF'
      kcall = 'ASK AT DESK'
      kitem = 'PASS'
    elsif collections.index('PBK')
      # Adult paperback
      kcoll = 'A'
      kloc = 'PBK'
      kcall = "PBK #{author}"
      kitem = 'BK'
    elsif collections.index('BABY')
      # Kids' board books
      kcoll = 'J'
      kloc = 'J'
      kcall = "BABY #{author}"
      kitem = 'BK'
    elsif collections.index('PIC')
      # Kids' picture books
      kcoll = 'J'
      kloc = 'J'
      kcall = "PIC #{author}"
      kitem = 'BK'
    elsif collections.index('EZ')
      # Kids' picture books
      kcoll = 'J'
      kloc = 'J'
      kcall = "EZ #{author}"
      kitem = 'BK'
    elsif collections.index('CD')
      # Adult CDs
      kcoll = 'A'
      kloc = 'CD'
      kcall = "CD #{author}"
      kitem = 'CD'
    elsif collection =~ /MUS/
      # Adult music CDs
      kcoll = 'A'
      kloc = 'CD'
      kcall = "MUS #{author}"
      kitem = 'MU'
    end
  end

  # Now handle special cases in collections or prefix
  if collections.index('LPE')
    # Large print editions
    kcoll = 'A'
    kloc = 'LP'
    if kcall == 'UNDEFINED'
      kcall = 'LPE ' + author
    else
      kcall = 'LPE ' + kcall
    end
    kitem = 'BK'
  end
  if collections.index('COMPUTERS') || collections.index('Computer')
    # Computers
    kcoll = 'A'
    kloc = 'STAFF'
    kcall = 'ASK AT DESK'
    kitem = 'PC'
  end
  if collections.index('KINDLE')
    # Kindle
    kcoll = 'A'
    kloc = 'STAFF'
    kcall = 'ASK AT DESK'
    kitem = 'ER'
  end
  if collection =~ /key/i
    # Keys
    kcoll = 'A'
    kloc = 'STAFF'
    kcall = 'ASK AT DESK'
    kitem = 'KEY'
  end
  if collection =~ /mag/i
    # Magazines
    kcoll = 'A'
    kloc = 'STAFF'
    kcall = 'ASK AT DESK'
    kitem = 'MAG'
  end
  if collection =~ /town|school/i
    # Town/school reports
    kcoll = 'A'
    kloc = 'VT'
    kcall = prefix + 'TOWN ' + author
    kitem = 'BK'
  end
  if collection =~ /map/i
    # Maps
    kcoll = 'A'
    kitem = 'MAP'
    kcall = 'MAP ' + author
  end
  if collection =~ /BP/
    # Blood pressure monitor
    kcoll = 'A'
    kloc = 'STAFF'
    kcall = 'ASK AT DESK'
    kitem = 'MX'
  end
  if collection =~ /CARD/
    # Credit cards
    kcoll = 'A'
    kloc = 'STAFF'
    kcall = 'ASK AT DESK'
    kitem = 'CARD'
  end

  # These modifiers have to be processed last.
  if prefixes.index('VT')
    # Vermont items: only use the VT prefix for adult non-fiction.
    # FIXME: how about biography?  (dewey || kitem == 'MAP' || kloc == 'BIO')
    if kcoll == 'A' && !collections.index('FIC')
      kcall = 'VT ' + kcall
      kloc = 'VT'
    end
    kcoll = 'VT' + kcoll
  end
  if collections.index('XMAS')
    # Christmas books
    kloc = 'XMAS'
  end
  if prefixes.index('STORAGE')
    kloc = 'STO'
  end
  if prefixes.index('REF')
    kitem = 'REF'
  end

  # Print derived Koha attributes.
  kcoll.strip!
  kloc.strip!
  kcall.strip!

  if dryrun
    puts("Koha coll: #{kcoll}")
    puts("Koha loc:  #{kloc}")
    puts("Koha call: #{kcall}")
    puts("Koha item: #{kitem}")
  end
  if kcoll + kloc + kitem =~ /UNDEFINED/
    warn("Record #{recno} (#{title},#{prefix},#{collection},#{author}) has an undefined Koha collection or location or item type!")
    return
  end

  # Make sure that sound recordings and movies have the correct item type.
  if record['245'] && record['245']['h']
    media = record['245']['h']
    expected_kitem = /#{kitem}/
    case media
    when /dvd|video|filmmaterial/i
      expected_kitem = /DVD|VC/
    when /cd|compact|book on cd|sound recording|mp3 talking/i
      expected_kitem = /CD/
    when /music/i
      expected_kitem = /MU/
    when /kit/i
      expected_kitem = /MX/
    end
    if kitem !~ expected_kitem
      warn("Record #{recno} (#{title},#{prefix},#{collection},#{author},#{barcode}) has media type #{media} but item type is #{kitem}, expected #{expected_kitem.source}!")
    end
  end

  # Convert holding acquisition date from YYMMDD to YYYY-MM-DD.
  holding_date = ''
  if record['008']
    rec = record['008'].value
    if rec =~ /^(\d\d)(\d\d)(\d\d)/
      year = $1
      if year > '60'
        year = '19' + year
      else
        year = '20' + year
      end
      holding_date = "#{year}-#{$2}-#{$3}"
    end
  end
      
  # Convert bib entry date from YYMMDD to YYYY-MM-DD.
  bib_date = ''
  if record['908']
    if rec = record['908']['a']
      if rec =~ /^(\d\d)(\d\d)(\d\d)/
	year = $1
	if year > '60'
	  year = '19' + year
	else
	  year = '20' + year
	end
	bib_date = "#{year}-#{$2}-#{$3}"
      end
    end
  end

  # Use the later of the two dates as the acquisition date.
  date = [bib_date, holding_date].max

  # Append 942 and 952 records required by Koha.
  unless dryrun
    record = cleanup_record(record)
    record.append(MARC::DataField.new(
      '942', ' ',  ' ',
      ['c', kitem]))
    record.append(MARC::DataField.new(
      '952', ' ',  ' ',
      ['8', kcoll],
      ['a', 'VSPS'],
      ['b', 'VSPS'],
      ['c', kloc],
      ['d', date],
      ['o', kcall],
      ['p', barcode],
      ['v', price],
      ['y', kitem]))
    writer.write(record)
  end
end

# Check arguments. First is input file.  Second is output file.
if ARGV.length < 2
   puts "usage: m8toutf8.rb [-n] [-u] infile outfile"
   puts "-n : don't write outfile, just print records from infile"
   puts "-u : use utf-8 encoding on infile instead of MARC-8"
   exit 1
end


dryrun = false
encoding = 'MARC-8'

nopts = 0
ARGV.each do |arg|
  if arg == '-n'
    dryrun = true
    nopts += 1
  elsif arg == '-u'
    encoding = 'utf-8'
    nopts += 1
  else
    break
  end
end
ARGV.shift(nopts)

input_file = ARGV[0]
output_file = ARGV[1]

unless dryrun
  if File.exist?(output_file)
    puts "#{output_file} exists; will not overwrite."
    exit 1
  end
end

puts("Reading #{input_file} using #{encoding} encoding")
reader = MARC::Reader.new(input_file,
                          :external_encoding => encoding,
			  :internal_encoding => "utf-8",
                          :validate_encoding => true)
unless dryrun
  puts("Writing #{output_file} using utf-8 encoding")
  writer = MARC::Writer.new(output_file)
end

# Read records, convert to UTF-8 and set Koha fields, write to new file.
print_rec = 0
recno = 0
for record in reader
  recno += 1
  convert_record(record, recno, dryrun, writer)
end
puts("#{recno} records handled\n")
unless dryrun
  writer.close()
end

