#!/usr/bin/env ruby

require 'marc'

def print_record(record, recno)
  # Print out title and author.
  puts("------ Record #{recno} ------")
  puts("title: '#{record['245']['a']}'")
  puts("subtitle: '#{record['245']['b']}'")
  if (record['100'])
    puts("author: '#{record['100']['a']}'")
  else
    puts("author: UNDEFINED!")
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
  if record['852']
    puts("branch (852-a): '#{record['852']['a']}'")
    puts("ILL branch (852-b): '#{record['852']['b']}'")

    # Parse prefix.
    prefix = record['852']['k']
    if prefix
      prefix.strip!
    else
      prefix = ''
    end
    puts("prefix (852-k): '#{prefix}'")
    prefixes = prefix.split

    # Parse collection.
    collection = record['852']['h']
    if collection
      collection.strip!
    else
      collection = ''
    end
    puts("collection (852-h): '#{collection}'")
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

    author = record['852']['i']
    if author
      author.strip!
    else
      author = ''
    end
    puts("author (852-i): '#{author}'")

    # Regularize the price.
    puts("price (852-9): '#{record['852']['9']}'")

    barcode = record['852']['p']
    if barcode
      barcode.strip!
    else
      warn("Title '#{record['245']['a']}' missing barcode")
      barcode = ''
    end
    puts("barcode (852-p): '#{barcode}'")
  end

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

  # Print Koha-specific records.
  if record['942']
    puts("Koha item type (942-c): '#{record['942']['c'] || "undefined"}'")
  end
  if record['952']
    puts("Koha home branch (952-a): '#{record['952']['a'] || "undefined"}'")
    puts("Koha holding branch (952-b): '#{record['952']['b']}'")
    puts("Koha collection (952-8): '#{record['952']['8'] || "undefined"}'")
    puts("Koha call number (952-o): '#{record['952']['o']}'")
    puts("Koha location (952-c): '#{record['952']['c']}'")
    puts("Koha price (952-v): '#{record['952']['v']}'")
    puts("Koha barcode (952-p): '#{record['952']['p'] || "undefined"}'")
    puts("Koha acq. date (952-d): '#{record['952']['d'] || "undefined"}'")
    puts("Koha item type (952-y): '#{record['952']['y'] || "undefined"}'")
  end

end

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
                            #:external_encoding => "cp866",
                            :external_encoding => "UTF-8",
                            #:external_encoding => "MARC-8",
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
