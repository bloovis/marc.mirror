#!/usr/bin/env ruby

require 'marc'

def print_record(record, recno)
  # Print out title and author.
  puts("------ Record #{recno} ------")
  if record['245']
    puts("title: '#{record['245']['a']}'")
    puts("subtitle: '#{record['245']['b']}'")
  end
  if (record['100'])
    puts("author: '#{record['100']['a']}'")
  else
    puts("author: UNDEFINED!")
  end

  # Print out ISBN.
  if record['020']
    puts("ISBN (020-a): '#{record['020']['a']}'")
  end

  # Print out 082 call number fields
  if record['082']
    puts("classification number (082-a): '#{record['082']['a']}'")
  end

  # Print out 245 media type.
  itemtype = 'BK'
  if record['245'] && record['245']['h']
    media = record['245']['h']
    puts("media type (245-h): '#{media}'")
    case media
    when /dvd|video|filmmaterial/i
      itemtype = 'DVD'
    when /cd|compact|book on cd|sound recording|mp3 talking/i
      itemtype = 'CD'
    when /music/i
      itemtype = 'MU'
    when /kit/i
      itemtype = 'MX'
    when /^$/
      itemtype = 'MX'
    end
  end

  # Print out 347 digital file encoding.
  if record['347'] && record['347']['b']
    encoding = record['347']['b']
    puts("file encoding (347-b): '#{encoding}'")
    case encoding
    when /blu-ray|dvd/i
      itemtype = 'DVD'
    when /cd|mp3/i
      itemtype = 'CD'
    end
  end

  # Print out 852 holding fields.
  holding_count = 0
  record.each_by_tag('852') do |field|
    holding_count += 1
    puts("M3 holding #{holding_count}:")
    puts("  branch (852-a): '#{field['a']}'")
    puts("  ILL branch (852-b): '#{field['b']}'")

    # Parse prefix.
    prefix = field['k']
    if prefix
      prefix.strip!
    else
      prefix = ''
    end
    puts("  prefix (852-k): '#{prefix}'")
    prefixes = prefix.split

    # Parse collection.
    collection = field['h']
    if collection
      collection.strip!
    else
      collection = ''
    end
    puts("  collection (852-h): '#{collection}'")
    case collection
    when /DVD/
      itemtype = 'DVD'
    when /CD/
      itemtype = 'CD'
    when /VID/
      itemtype = 'VC'
    when /computer|laptop/i
      itemtype = 'PC'
    when /pass/i
      itemtype = 'PASS'
    when /CAS/
      itemtype = 'CAS'
    when /CR MAGS/
      itemtype = 'MAG'
    end
    if itemtype == 'DVD' && collection != 'DVD'
      warn("Title '#{record['245']['a']}' has item type DVD but collection is '#{collection}'")
    end

    author = field['i']
    if author
      author.strip!
    else
      author = ''
    end
    puts("  author (852-i): '#{author}'")
    puts("  Mandarin call number: " + "#{prefix} #{collection} #{author}".strip)

    # Print the price.
    puts("  price (852-9): '#{field['9']}'")

    barcode = field['p']
    if barcode
      barcode.strip!
    else
      warn("Title '#{record['245']['a']}' missing barcode")
      barcode = ''
    end
    puts("  barcode (852-p): '#{barcode}'")
  end	# of all 852 fields

  # Print electronic location.
  if record['856']
    if url = record['856']['u']
      puts("URL (856-u): '#{url}'")
    end
  end

  # Print acquisition date.  Convert to yymmdd to YYYY-MM-DD.
  if record['008']
    rec = record['008'].value
    if rec =~ /^(\d\d)(\d\d)(\d\d)/
      year = $1
      if year > '60'
	year = '19' + year
      else
	year = '20' + year
      end
      date = "#{year}-#{$2}-#{$3}"
      puts("Date (008): #{date}")
    end
  end


  # Print bib date.  Convert to yymmdd to YYYY-MM-DD.
  if record['908'] && rec = record['908']['a']
    if rec =~ /^(\d\d)(\d\d)(\d\d)/
      year = $1
      if year > '60'
	year = '19' + year
      else
	year = '20' + year
      end
      date = "#{year}-#{$2}-#{$3}"
      puts("Bib date (908): #{date}")
    end
  end


  # Print Koha-specific records.
  if record['942']
    puts("Koha item type (942-c): '#{record['942']['c'] || "undefined"}'")
  end

  holding_count = 0
  record.each_by_tag('952') do |field|
    holding_count += 1
    puts("Koha holding #{holding_count}:")
    puts("  home branch (952-a): '#{field['a'] || "undefined"}'")
    puts("  holding branch (952-b): '#{field['b']}'")
    puts("  collection (952-8): '#{field['8'] || "undefined"}'")
    puts("  call number (952-o): '#{field['o']}'")
    puts("  location (952-c): '#{field['c']}'")
    puts("  price (952-v): '#{field['v']}'")
    puts("  barcode (952-p): '#{field['p'] || "undefined"}'")
    puts("  acq. date (952-d): '#{field['d'] || "undefined"}'")
    puts("  item type (952-y): '#{field['y'] || "undefined"}'")
  end

end

if ARGV.length < 1
   puts "usage: printmarc.rb [-m] marcfile..."
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

# reading records from a batch file
firstrec = 1
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
    begin
      record = reader.decode(raw)
    rescue Encoding::InvalidByteSequenceError => e
      record = MARC::Reader.decode(raw,
                                   :external_encoding => "MARC-8",
                                    :invalid => :replace)
      puts("While decoding record #{recno}:", e.message, record)
      print_record(record, recno)
    end
    begin
      if (recno >= firstrec)
        print_record(record, recno)
      end
    rescue => e
      puts("While printing record #{recno}:", e.message, record)
    end
  end
  puts("#{recno} records handled\n")
end
