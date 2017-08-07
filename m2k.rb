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
require 'date'

# Take an 852 holding field, and some other Mandarin-specific
# info in a hash (m), and return a hash (k) containing the equivalent Koha
# info.  This function contains many library-specific rules that
# you will probably need to change for your installation.

def get_holding_info(field, m, dryrun, recno)
  # Hash of Koha-specific holding info.
  k = {}

  # Calculate age of item in days.  If less than 180 days,
  # it's a new book.
  begin
    new_book = (DateTime.now - Date.parse(m[:date])).to_i < 180
  rescue
    puts "Invalid date '#{m[:date]}' in record #{recno} (#{m[:title]}): assuming not a new book"
    new_book = false
  end

  # Get prefix and split it into components.
  prefix = field['k']
  if prefix
    prefix.strip!
  else
    prefix = ''
  end
  prefixes = prefix.split

  # Get collection.
  collection = field['h']
  if collection
    collection.strip!
  else
    collection = ''
  end

  # Split collection into components.  If one of those components
  # is numeric, treat it as a Dewey number.
  collections = collection.split
  if collection =~ /(\d+[\d.\/]*)/
    dewey = $1
    if dryrun
      puts("Dewey: #{dewey}")
    end
  else
    dewey = nil
  end

  # Get author.  For fiction and easy readers, we take the longer of either the
  # Mandarin author (852$i) or the standard MARC author (100$a).
  mandarin_author = field['i']
  if mandarin_author
    mandarin_author.strip!
  else
    mandarin_author = ''
  end
  marc_author = ''
  if collections.index('FIC') || collections.index('EZ')
    if m[:surname]
      marc_author = m[:surname].upcase
    end
  end
  if marc_author.length > mandarin_author.length
    author = marc_author
  else
    author = mandarin_author
  end

  # Regularize the price.
  k[:price] = field['9'] || ''
  if k[:price] =~ /(\d+\.?\d+)/
    k[:price] = $1
  else
    k[:price] = ''
  end

  # Extract the barcode
  k[:barcode] = field['p']

  # Print the Mandarin info
  if dryrun
    puts("branch (852): '#{field['a']}'")
    puts("ILL branch (852): '#{field['b']}'")
    puts("prefix (852): '#{prefix}'")
    puts("collection (852): '#{collection}'")
    puts("author (852): '#{author}'")
    puts("price (852): '#{k[:price]}'")
    puts("barcode (852): '#{k[:barcode]}'")
  end

  # Break down the various combinations of prefix(es), collection(s), and author
  # as found in the MARC 852 field.  From these, determine Koha collection,
  # location, call number, and item type.
  k[:coll] = 'UNDEFINED'
  k[:loc]  = 'UNDEFINED'
  k[:call] = 'UNDEFINED'
  k[:item] = 'UNDEFINED'

  if prefixes.index('J')
    # Kids' items
    k[:coll] = 'J'
    k[:loc] = 'J'
    if collections.index('CD')
      # Kids' CDs
      k[:loc] = 'JCD'
      k[:call] = "J CD #{author}"
      k[:item] = 'CD'
    elsif collections.index('DVD')
      k[:loc] = 'JDVD'
      k[:call] = "J DVD #{author}"
      k[:item] = 'DVD'
    elsif dewey
      # Kids' non-fiction
      k[:loc] = 'JNFIC'
      k[:call] = "J #{dewey} #{author}"
      k[:item] = 'BK'
    elsif collections.index('FIC')
      # Kids' fiction
      k[:loc] = 'JFIC'
      k[:call] = "J FIC #{author}"
      k[:item] = 'BK'
    elsif collections.index('BIO')
      # Kids' biography
      k[:loc] = 'JBIO'
      k[:call] = "J BIO #{author}"
      k[:item] = 'BK'
    elsif collection =~ /CAS/
      # Kids' cassettes
      k[:call] = "J CAS #{author}"
      k[:item] = 'CAS'
    elsif collections.index('VID')
      # Kids' video cassettes
      k[:loc] = 'CD'
      k[:call] = "J VID #{author}"
      k[:item] = 'VC'
    elsif collections.index('SPANISH')
      # Kids' Spanish books
      k[:call] = "J SPANISH #{author}"
      k[:item] = 'BK'
    end
  elsif prefixes.index('YA')
    # YA items
    k[:coll] = 'YA'
    if dewey
      if dewey =~ /741\.5/
	# YA graphic novel
	k[:loc] = 'YAGN'
	k[:call] = "YA #{dewey} #{author}"
      else
	# Other YA non-fiction is stored with adult non-fiction,
	# but we keep the YA prefix on the call number.
	k[:loc] = 'NFIC'
	k[:call] = "YA #{dewey} #{author}"
      end
      k[:item] = 'BK'
    elsif collections.index('FIC')
      # YA fiction
      k[:loc] = 'YAFIC'
      k[:call] = "YA FIC #{author}"
      k[:item] = 'BK'
    elsif collections.index('DVD')
      # YA DVD, fiction or non-fiction
      k[:loc] = 'DVD'
      k[:call] = "DVD #{author}"
      k[:item] = 'DVD'
    elsif collections.index('BIO')
      # YA biography
      k[:loc] = 'BIO'
      k[:call] = "BIO #{author}"
      k[:item] = 'BK'
    elsif collections.index('CD')
      # YA audiobooks
      k[:loc] = 'CD'
      k[:call] = "CD #{author}"
      k[:item] = 'CD'
    elsif collections.index('PBK')
      # YA paperback
      k[:loc] = 'PBK'
      k[:call] = "PBK #{author}"
      k[:item] = 'BK'
    end
  else
    # Adult items (and some kids' items that have no prefix)
    if dewey
      # Adult non-fiction
      k[:coll] = 'A'
      k[:call] = "#{dewey} #{author}"
      if new_book
	k[:loc] = 'NEWNFIC'
	k[:item] = 'NEW'
      else
        k[:loc] = 'NFIC'
        k[:item] = 'BK'
      end
    elsif collections.index('FIC')
      # Adult fiction
      k[:coll] = 'A'
      k[:call] = "FIC #{author}"
      if new_book
	k[:loc] = 'NEWFIC'
	k[:item] = 'NEW'
      else
	if author > 'COBEN'
	  # Downstairs
	  k[:loc] = 'FICD'
	else
	  # Upstairs
	  k[:loc] = 'FICU'
	end
	k[:item] = 'BK'
      end
    elsif collections.index('DVD')
      # Adult DVD, fiction or non-fiction
      k[:coll] = 'A'
      k[:loc] = 'DVD'
      k[:call] = "DVD #{author}"
      k[:item] = 'DVD'
    elsif collections.index('BIO') || collections.index('Bio')
      # Adult biography
      k[:coll] = 'A'
      k[:call] = "BIO #{author}"
      if new_book
	k[:loc] = 'NEWBIO'
	k[:item] = 'NEW'
      else
        k[:loc] = 'BIO'
        k[:item] = 'BK'
      end
    elsif collection =~ /CAS/
      # Adult cassette
      k[:coll] = 'A'
      k[:loc] = 'CD'
      k[:call] = "CAS #{author}"
      k[:item] = 'CAS'
    elsif collection =~ /VID/
      # Adult video cassette
      k[:coll] = 'A'
      k[:loc] = 'CD'
      k[:call] = "VID #{author}"
      k[:item] = 'VC'
    elsif collection =~ /pass/i
      # Park/museum pass
      k[:coll] = 'A'
      k[:loc] = 'STAFF'
      k[:call] = 'ASK AT DESK'
      k[:item] = 'PASS'
    elsif collections.index('PBK')
      # Adult paperback
      k[:coll] = 'A'
      k[:loc] = 'PBK'
      k[:call] = "PBK #{author}"
      k[:item] = 'BK'
    elsif collections.index('BABY')
      # Kids' board books
      k[:coll] = 'J'
      k[:loc] = 'BABY'
      k[:call] = "BABY #{author}"
      k[:item] = 'BK'
    elsif collections.index('PIC')
      # Kids' picture books
      k[:coll] = 'J'
      k[:loc] = 'PIC'
      k[:call] = "PIC #{author}"
      k[:item] = 'BK'
    elsif collections.index('EZ')
      # Kids' Easy reader books
      k[:coll] = 'J'
      k[:loc] = 'EZ'
      k[:call] = "EZ #{author}"
      k[:item] = 'BK'
    elsif collections.index('CD')
      # Adult CDs
      k[:coll] = 'A'
      k[:loc] = 'CD'
      k[:call] = "CD #{author}"
      k[:item] = 'CD'
    elsif collection =~ /MUS/
      # Adult music CDs
      k[:coll] = 'A'
      k[:loc] = 'CD'
      k[:call] = "MUS #{author}"
      k[:item] = 'MU'
    end
  end

  # Now handle special cases in collections or prefix
  if collections.index('LPE')
    # Large print editions
    k[:coll] = 'A'
    k[:loc] = 'LP'
    if k[:call] == 'UNDEFINED'
      k[:call] = 'LPE ' + author
    else
      k[:call] = 'LPE ' + k[:call]
    end
    k[:item] = 'BK'
  end
  if collections.index('COMPUTERS') || collections.index('Computer')
    # Computers
    k[:coll] = 'A'
    k[:loc] = 'STAFF'
    k[:call] = 'ASK AT DESK'
    k[:item] = 'PC'
  end
  if collections.index('KINDLE')
    # Kindle
    k[:coll] = 'A'
    k[:loc] = 'STAFF'
    k[:call] = 'ASK AT DESK'
    k[:item] = 'ER'
  end
  if collection =~ /key/i
    # Keys
    k[:coll] = 'A'
    k[:loc] = 'STAFF'
    k[:call] = 'ASK AT DESK'
    k[:item] = 'KEY'
  end
  if collection =~ /mag/i
    # Magazines
    k[:coll] = 'A'
    k[:loc] = 'STAFF'
    k[:call] = 'ASK AT DESK'
    k[:item] = 'MAG'
  end
  if collection =~ /town|school/i
    # Town/school reports
    k[:coll] = 'A'
    k[:loc] = 'VT'
    k[:call] = prefix + 'TOWN ' + author
    k[:item] = 'BK'
  end
  if collection =~ /map/i
    # Maps
    k[:coll] = 'A'
    k[:item] = 'MAP'
    k[:call] = 'MAP ' + author
  end
  if collection =~ /BP/
    # Blood pressure monitor
    k[:coll] = 'A'
    k[:loc] = 'STAFF'
    k[:call] = 'ASK AT DESK'
    k[:item] = 'MX'
  end
  if collection =~ /CARD/
    # Credit cards
    k[:coll] = 'A'
    k[:loc] = 'STAFF'
    k[:call] = 'ASK AT DESK'
    k[:item] = 'CARD'
  end

  # These modifiers have to be processed last.
  if prefixes.index('VT')
    # Vermont items: only use the VT prefix for adult non-fiction.
    # FIXME: how about biography?  (dewey || k[:item] == 'MAP' || k[:loc] == 'BIO')
    if k[:coll] == 'A' && !collections.index('FIC')
      k[:call] = 'VT ' + k[:call]
      k[:loc] = 'VT'
    end
    k[:coll] = 'VT' + k[:coll]
  end
  if collections.index('XMAS')
    # Christmas books
    k[:loc] = 'XMAS'
  end
  if prefixes.index('STORAGE')
    k[:loc] = 'STO'
  end
  if prefixes.index('REF')
    k[:item] = 'REF'
  end

  # Print derived Koha attributes.
  k[:coll].strip!
  k[:loc].strip!
  k[:call].strip!

  if dryrun
    puts("Koha coll: #{k[:coll]}")
    puts("Koha loc:  #{k[:loc]}")
    puts("Koha call: #{k[:call]}")
    puts("Koha item: #{k[:item]}")
  end
  if k[:coll] + k[:loc] + k[:item] =~ /UNDEFINED/
    warn("Record #{recno} (#{m[:title]},#{prefix},#{collection},#{author}) has an undefined Koha collection or location or item type!")
    return nil
  end

  # Make sure that sound recordings and movies have the correct item type.
  if m[:media]
    expected_kitem = /#{k[:item]}/
    case m[:media]
    when /dvd|video|filmmaterial/i
      expected_kitem = /DVD|VC/
    when /cd|compact|book on cd|sound recording|mp3 talking/i
      expected_kitem = /CD/
    when /music/i
      expected_kitem = /MU/
    when /kit/i
      expected_kitem = /MX/
    end
    if k[:item] !~ expected_kitem
      warn("Record #{m[:recno]} (#{m[:title]},#{prefix},#{collection},#{author},#{k[:barcode]}) has media type #{m[:media]} but item type is #{k[:item]}, expected #{expected_kitem.source}!")
    end
  end

  # Return hash of info extracted or deduced from the 852 field.
  return k
end

# Convert a Mandarin-generated MARC record to one
# suitable for importing into Koha.  Most fields
# are copied verbatim, some are ignored, and the
# 852 fields are converted.

def convert_record(mandarin_record, recno, dryrun, writer)
  if dryrun
    puts("------ Record #{recno} ------")
  end

  # Create an output record, which will contain the non-Koha
  # fields from the Mandarin record, plus our new Koha-specific
  # fields.
  record = MARC::Record.new

  # Copy the leader, which contains important information about
  # material type.
  record.leader = mandarin_record.leader

  # Convert bib entry date from YYMMDD to YYYY-MM-DD.  We have to handle
  # this before iterating through the fields, because 908 appears
  # after the holding fields (852).
  bib_date = ''
  if mandarin_record['908']
    if date = mandarin_record['908']['a']
      if date =~ /^(\d\d)(\d\d)(\d\d)/
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

  # A hash of information that will get initialized properly as
  # we parse the fields from the Mandarin record.
  m = {}
  m[:title] = nil
  m[:surname] = nil
  m[:media] = nil
  m[:date] = ''
  m[:recno] = recno

  # For each field in the old record, copy it, ignore it,
  # or (in the case of a holding record) convert it.
  holding_count = 0
  mandarin_record.each do |field|
    case field.tag
    when '008'
      # Convert holding acquisition date from YYMMDD to YYYY-MM-DD.
      holding_date = ''
      date = field.value
      if date =~ /^(\d\d)(\d\d)(\d\d)/
	year = $1
	if year > '60'
	  year = '19' + year
	else
	  year = '20' + year
	end
	holding_date = "#{year}-#{$2}-#{$3}"
      end

      # Use the later of the two dates as the Koha acquisition date.
      m[:date] = [bib_date, holding_date].max

      unless dryrun
        record.append(field)
      end
    when '100'
      # Get author info.
      full_author = field['a']
      if full_author
	m[:surname] = full_author.split(/\s*[,.\s]\s*/)[0]
      end
      if dryrun
	puts("author (100): '#{full_author}")
      else
        record.append(field)
      end
    when '245'
      # Get the title and media type.
      m[:title] = field['a']
      if field['h']
	m[:media] = field['h']
      end
      if dryrun
	puts("title: '#{m[:title]}', media type: #{m[:media]}")
      else
        record.append(field)
      end
    when '852'
      k = get_holding_info(field, m, dryrun, recno)
      if k.nil?
	puts "Ignoring 852 field in record #{recno} due to errors"
	next
      end

      # Append 942 and 952 fields required by Koha.
      holding_count += 1
      unless dryrun
	if holding_count == 1
	  # Add only one bib record item type.
	  record.append(MARC::DataField.new(
	    '942', ' ',  ' ',
	    ['c', k[:item]]))
	end

	# Add this holding record.
	record.append(MARC::DataField.new(
	  '952', ' ',  ' ',
	  ['8', k[:coll]],
	  ['a', 'VSPS'],
	  ['b', 'VSPS'],
	  ['c', k[:loc]],
	  ['d', m[:date]],
	  ['o', k[:call]],
	  ['p', k[:barcode]],
	  ['v', k[:price]],
	  ['y', k[:item]]))
      end
    else
      # Ignore Mandarin-specific fields.
      unless dryrun || ['852', '908', '942', '952'].index(field.tag)
        record.append(field)
      end
    end	# cases
  end # each field

  # Write out the converted record.
  unless dryrun
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
  #puts "processed record #{recno}"
end
puts("#{recno} records handled\n")
unless dryrun
  writer.close()
end

