#!/usr/bin/env ruby

# This script converts a CSV file containing a dump
# of a book catalog from collectorz.com to a MARC
# catalog that can be imported into Koha.

require 'csv'
require 'marc'
require 'zoom'

# Column names indexed by a symbol that will be used
# as an index to inds.

book_columns = {
  author:	"Author",
  title:	"Title",
  publisher:	"Publisher",
  pubdate:	"Publication Date",
  date:		"Added Date",
  dewey:	"Dewey",
  genre:	"Genre",
  lcclass:	"LC Classification",
  lccontrol:	"LC Control No.",
  subject:	"Subject",
  dimensions:	"Dimensions",
  format:	"Format",
  isbn:		"ISBN",
  pages:	"Pages",
  language:	"Language",
  subtitle:	"Sub Title",
  location:	"Location",
  purchdate:	"Purchase Date",
  price:	"Purchase Price",
  index:	"Index"
}

book_columns_windows = {
  author:	"Author",
  title:	"Title",
  publisher:	"Publisher",
  pubdate:	"Publication Year",
  date:		"Date Added",
  dewey:	"Dewey",
  genre:	"Genre",
  lcclass:	"LoC Classification",
  lccontrol:	"LoC Control Number",
  subject:	"Subject",
  format:	"Format",
  isbn:		"ISBN",
  pages:	"No. of Pages",
  language:	"Language",
  subtitle:	"Sub Title",
  location:	"Location",
  purchdate:	"Purchase Date",
  price:	"Purchase Price",
  index:	"Index",
  plot:		"Plot"
}

movie_columns = {
  title:	"Title",
  release:	"Release Date",
  genre:	"Genre",
  runtime:	"Runtime",
  director:	"Director",
  format:	"Format",
  distributor:	"Distributor",
  date:		"Added Date",
  actor:	"Actor",
  producer:	"Producer",
  studio:	"Studio",
  nrdisks:	"Nr Disks",
  index:	"Index",
  rating:	"Audience Rating",
  edition:	"Edition",
  color:	"Color",
  region:	"Region"
}

# The header line produced by the Collectorz Windows app has
# labels that differ from those produced by the web app (!).

movie_columns_windows = {
  title:	"Title",
  release:	"Movie Release Year",
  genre:	"Genre",
  runtime:	"Running Time",
  director:	"Director",
  format:	"Format",
  distributor:	"Distributor",
  date:		"Purchase Date",
  actor:	"Actor",
  producer:	"Producer",
  studio:	"Studio",
  nrdisks:	"No. of Discs/Tapes",
  index:	"Index",
  plot:		"Plot",
  trailer:	"Trailer URLs",
  edition:	"Edition",
  cine:		"Cinematography",
  music:	"Musician",
  writer:	"Writer",
  extras:	"Extra Features",
  ratio:	"Screen Ratio",
  rating:	"Audience Rating",
  color:	"Color",
  layers:	"Layers",
  region:	"Region"
}

# Indices into a data row, indexed by column symbol.
# For example, to get the index for the dewey number,
# use inds[:dewey].  Then, to fetch the dewew number
# for a row, use row[inds[:dewey]].

inds = {}

# Map of location code to collections.
# Collections are A (adult), YA (young adult) and J (children).
# This library used location strings like this:
#   YA = Young Adult Fiction
# where the word to the left of the = appears to be
# a location code, and the words to the right appear
# to be a verbose description. Unfortunately, this library
# used "P" as the location code for both poetry and picture
# books, so the code below will use "PIC"
# for picture books.

locs = {
  'AB'  => 'A',		# Audio Books
  'BB'  => 'J',		# Board Book
  'B'   => 'A',		# Biography & Memoir
  'E'   => 'J',		# New Readers
  'F'   => 'A',		# Adult Fiction
  'JF'  => 'J',		# Juvenile Fiction
  'JNF' => 'J',		# Jr & YA NON Fiction
  'LP'  => 'A',		# Large Print
  'NF'  => 'A',		# Adult NON Fiction
#  'P'   => 'J',		# Picture Books
  'P'   => 'A',		# Poetry
  'YA'  => 'YA'		# Young Adult Fiction
}

# Convert a Collectorz date into an ISO date compatible with Koha.
# The incoming date can be either of these formats:
#   Mon DD, YYYY
#   MM/DD/YYYY
# Convert these to ISO:
#   YYYY-MM-DD

def convertdate(date)
  if date =~ /^(\w\w\w) (\d\d), (\d\d\d\d)$/
    month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
	     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'].index($1) + 1
    day = $2
    year = $3
    return year + '-' + sprintf("%02d", month) + '-' + day
  elsif date =~ /^(\d+)\/(\d+)\/(20\d\d)/
    month = $1.to_i
    day = $2.to_i
    year = $3.to_i
    return sprintf("%04d-%02d-%02d", year, month, day)
  else
    return ''
  end
end

# Determine the three-letter movie genre abbreviation for use
# in the call number (spine tag).  Unfortunately, in CSV files exported
# from the Collectorz web app, the genre field can contain multiple genres,
# apparently in alphabetical order.  This problem does not occur in
# CSV files exported from the Collectorz Windows app.
# Some examples:
#   Action, Adventure, Biography, Drama, History, Music, Romance, War
#   Action, Adventure, Animation, Anime, Drama, Fantasy, Mystery, Science Fiction, Thriller
#   Comedy, Drama, History
# There is no obvious way to determine the genre tag
# in actual use.  Picking the first one is almost certainly
# going to be wrong, because the alphabetical order means
# that Action would always win out over, say, Science Fiction.
# We could say that certain genres have priority.
# For example, we might prioritize them as follows:
#   Animation
#   Family
#   Comedy
# But this is completely arbitrary, and likely to be wrong most
# of the time.  We will just have to pick one genre somehow,
# and then correct it in the catalog when the item is checked
# out the first time (which we have to do anyway to get
# the correct barcode into the catalog).

def shortgenre(genres, windows)
  genre3 = nil
  unless windows
    if genres.index('Animation')
      genre3 = 'ANI'
    elsif genres.index('Family')
      genre3 = 'FAM'
    elsif genres.index('Comedy')
      genre3 = 'COM'
    elsif genres.index('Science Fiction')
      genre3 = 'SCI'
    end
  end
  unless genre3
    firstgenre = genres[0]
    if firstgenre
      genre3 = firstgenre[0..2].upcase
    end
  end
  return genre3 || ''
end

# Calculate a three-character upper-case abbreviation of the title, without
# a leading "the" or "a".

def shorttitle(title)
  title3 = ''
  if title
    if title =~ /^(the |a )?(.*)/i
      title3 = $2[0..2].upcase
    else
      title3 = title[0..2].upcase
    end
  end
  return title3
end

# Fix a couple of spurious HTML entities that found their way into
# various fields in the CSV file.

def fixentities(s)
  return s.gsub(/&apos;?/, "'").gsub(/&amp;?/, '&')
end

# Convert a row from a CSV book catalog to a Koha-compatible
# MARC record.

def convertbook(row, inds, dryrun, use_z3950, windows, locs, writer)
  isbn = row[inds[:isbn]]
  if dryrun
    puts "ISBN: #{isbn} Title: #{row[inds[:title]]} Subtitle: #{row[inds[:subtitle]]} Author: #{row[inds[:author]]}"
  else
    # Extract a few fields from the CSV line that we will need later.
    author = row[inds[:author]]
    title = row[inds[:title]]
    genre = row[inds[:genre]]
    if genre
      if windows
	genres = genre.split(/\s*;\s*/)
      else
	genres = genre.split(/\s*,\s*/)
      end
    end

    # The locations look like: JF = Juvenile Fiction
    # Use the first word as an index to the locs hash,
    # which gets us the collection code.
    loc = row[inds[:location]]
    location = ''
    if loc =~ /^(\w+) (.*)/
      location = $1
      remainder = $2
      collection = locs[location]
      unless collection
	puts "Unrecognized location #{location} for #{title}"
      end

      # Special case for "P", which is (mistakenly?) used for
      # both Picture Books and Poetry.
      if location == 'P'
	if remainder =~ /Picture/
	  location = 'P'
	  collection = 'J'
	else
	  location = 'PO'
	  collection = 'A'
	end
      end
    else
      puts "Invalid location #{location} for #{title}"
    end

    # Try to fetch a MARC record from a Z39.50 server.
    record = nil
    if isbn =~ /^\d+$/ && use_z3950
      record = get_z3950(isbn)
    end

    # If the record can't be found with Z39.50, create one from scratch,
    # filling in as much as we can from the Collectorz info.
    unless record
      record = MARC::Record.new

      # IBSN
      if isbn && isbn.length > 0
	record.append(MARC::DataField.new(
	  '20',' ',' ',
	  ['a', isbn]))
      end

      # Author
      if author && author.length > 0
	record.append(MARC::DataField.new(
	  '100','0',' ',
	  ['a', author]))
      end

      # Title/Subtitle
      if title && title.length > 0
	field = MARC::DataField.new(
	  '245','0','0',
	  ['a', title])
	subtitle = row[inds[:subtitle]]
	if subtitle && subtitle.length > 0
	  field.append(MARC::Subfield.new('b', subtitle))
	end
	if location == 'LP'
	  field.append(MARC::Subfield.new('h', 'large print'))
	end
	record.append(field)
      end

      # Add each subject to the record.
      subject = row[inds[:subject]]
      if subject
	if windows
	  subjects = subject.split(/\s*;\s*/)
	else
	  subjects = subject.split(/\s*,\s*/)
	end
	subjects.each do |s|
	  s2 = fixentities(s)
	  record.append(MARC::DataField.new(
	    '653', ' ', '0',
	    ['a', s2]))
	end
      end

      # Add each genre to the record.
      if genre
	genres.each do |g|
	  g2 = fixentities(g)
	  record.append(MARC::DataField.new(
	    '653', ' ', '6',
	    ['a', g2]))
	end
      end

      # Library of Congress classification
      lcclass = row[inds[:lcclass]]
      if lcclass && lcclass.length > 0
	classno, cutters = lcclass.split(' ', 2)
	field = MARC::DataField.new(
	  '50','0','0',
	  ['a', classno])
        if cutters && cutters.length > 0
	  field.append(MARC::Subfield.new('b', cutters))
	end
	record.append(field)
      else
	# puts "Nil lcclass for #{title}"
      end

      # Library of Congress control number
      lcno = row[inds[:lccontrol]]
      if lcno && lcno.length > 0
	record.append(MARC::DataField.new(
	  '10',' ',' ',
	  ['a', lcno]))
      end

      # Pages, format, dimensions
      pages = row[inds[:pages]]
      format = row[inds[:format]]
      dimind = inds[:dimensions]
      if dimind
	dimensions = row[dimind]
      else
	dimensions = ''
      end
      if pages && pages.length > 0
	field = MARC::DataField.new(
	  '300',' ',' ',
	  ['a', "#{pages} p." ])
	if format && format.length > 0
	  field.append(MARC::Subfield.new('b', format))
	end
	if dimensions && dimensions.length > 0
	  field.append(MARC::Subfield.new('b', dimensions))
	end
	record.append(field)
      end

      # Publisher and publication date
      publisher = row[inds[:publisher]]
      pubdate = row[inds[:pubdate]]
      if publisher && publisher.length > 0
	p2 = fixentities(publisher)
	field = MARC::DataField.new(
	  '260',' ',' ',
	  ['b', p2])
	if pubdate && pubdate.length > 0
	  field.append(MARC::Subfield.new('c', pubdate))
	end
	record.append(field)
      end
    end

    # Get plot (present only for Windows-produced CSV files)
    plotind = inds[:plot]
    if plotind
      plot = row[plotind]
      if plot && plot.length > 0
	record.append(MARC::DataField.new(
	  '520',' ',' ',
	  ['a', plot]))
      end
    end

    # Get Dewey number.
    dewey = row[inds[:dewey]]
    if dewey && dewey.length > 0
	record.append(MARC::DataField.new(
	  '82','0','4',
	  ['a', dewey],
	  ['2', '22']))
    else
      dewey = ''
    end

    # Determine Koha holding information.

    # Convert date to ISO format.
    datestr = convertdate(row[inds[:date]])

    # Get Title abbreviation.
    title3 = shorttitle(title)

    # Somehow determine the surname so we can figure what is
    # on the spine tag, hence in the call number.  Unfortuately,
    # the author field in collectorz doesn't put the surname first,
    # and it can look like any of the following:
    #   Peter Ackroyd
    #   David A. Aguilar
    #   Georgina Andrews, Kate Knighton
    #   The Metropolitan Museum of Art, N.Y. New York
    #   <empty string>
    author3 = ''
    if author
      authors = author.split(',')
      firstauthor = authors[0]
      if firstauthor
	surname = firstauthor.split[-1]
	author3 = surname[0..2].upcase
      end
    end

    # Determine the call number (found on the spine tag).
    if location
      call = location + ' '
      case location
      when 'F'
	call += author3
      when 'B'
	call += author3
      when 'NF'
	call += dewey + ' ' + author3
      when 'P'
	call += author3
      when 'E'
	call += author3
      when 'BB'
	call += author3
      when 'JF'
	call += author3
      when 'YA'
	call += author3
      when 'JNF'
	call += dewey + ' ' + author3
      when 'AB'
	call += author3
      end
    else
      call = ''
    end
    call.strip!

    # Append Koha holding information.
    record.append(MARC::DataField.new(
      '952', ' ',  ' ',
      ['8', collection],
      ['a', 'RCML'],
      ['b', 'RCML'],
      ['c', location],
      ['d', datestr],
      ['o', call],
      ['y', 'BK']))
    writer.write(record)
  end
end

# Convert a row from a CSV movie catalog to a Koha-compatible
# MARC record.

def convertmovie(row, inds, dryrun, windows, writer)
  if dryrun
    puts "Title: #{row[inds[:title]]} Release: #{row[inds[:release]]} Genre: #{row[inds[:genre]]}"
    puts "  Runtime: #{row[inds[:runtime]]} Director: #{row[inds[:director]]} Format #{row[inds[:format]]}"
    puts "  Distributor: #{row[inds[:distributor]]} Added Date: #{row[inds[:date]]}"
  else
    record = MARC::Record.new

    # Title
    title = row[inds[:title]]
    if title && title.length > 0
      record.append(MARC::DataField.new(
	'245','0','0',
	['a', title],
	['h', 'videorecording']))
    else
      puts "Movie added #{row[inds[:date]]} has no title!"
    end

    # Get the title abbreviation.
    title3 = shorttitle(title)

    # Get the run time.
    runtime = row[inds[:runtime]]
    if runtime && runtime.length > 0
      runtime.gsub!(/ mins/, '')
      record.append(MARC::DataField.new(
	'306',' ',' ',
	['a', sprintf("%06d", runtime.to_i)]))
    end

    # Get the number of disks.
    nrdisks = row[inds[:nrdisks]]
    if nrdisks && nrdisks.length > 0
      suffix = nrdisks.to_i == 1 ? '' : 's'
      if runtime && runtime.length > 0
	field = MARC::DataField.new(
	  '300',' ',' ',
	  ['a', sprintf("%s videodisc%s (%s min.)", nrdisks, suffix, runtime)])
      else
	field = MARC::DataField.new(
	  '300',' ',' ',
	  ['a', sprintf("%s videodisc%s", nrdisks, suffix)])
      end
      # Get color.
      color = row[inds[:color]]
      if color && color.length > 0
	field.append(MARC::Subfield.new('b', color))
      end
      record.append(field)
    end

    # Get genre(s).
    genre = row[inds[:genre]]
    if genre && genre.length > 0
      genres = genre.split(/\s*,\s*/)
      genres.each do |g|
        g2 = fixentities(g)
	record.append(MARC::DataField.new(
	  '653', ' ', '6',
	  ['a', g2]))
      end
    end

    # Distributor and release date.  The release format is
    # inconsistent: sometimes it is a year (e.g., 2009),
    # but sometimes it is a full date (e.g., Jan 01, 2017).
    # So just take the final number as the date.
    distributor = row[inds[:distributor]]
    release = row[inds[:release]]
    if distributor && release
      if release =~ /(\d+)$/
	release = $1
      end
      record.append(MARC::DataField.new(
	'260',' ',' ',
	['b', distributor],
	['c', release]))
    end

    # Get director.
    director = row[inds[:director]]
    if director && director.length > 0
      record.append(MARC::DataField.new(
	'700','1',' ',
	['a', director],
	['e', 'film director']))
    end

    # Get writer
    screenwriterind = inds[:writer]
    if screenwriterind
      screenwriter = row[screenwriterind]
      if screenwriter && screenwriter.length > 0
	record.append(MARC::DataField.new(
	  '700','1',' ',
	  ['a', screenwriter],
	  ['e', 'screenwriter']))
      end
    end

    # Get cinematographer.
    cineind = inds[:cine]
    if cineind
      cine = row[cineind]
      if cine && cine.length > 0
	record.append(MARC::DataField.new(
	  '700','1',' ',
	  ['a', cine],
	  ['e', 'cinematographer']))
      end
    end

    # Get musician.
    musicind = inds[:music]
    if musicind
      music = row[musicind]
      if music && music.length > 0
	record.append(MARC::DataField.new(
	  '700','1',' ',
	  ['a', music],
	  ['e', 'musician']))
      end
    end

    # Get producer.
    producer = row[inds[:producer]]
    if producer && producer.length > 0
      record.append(MARC::DataField.new(
	'508',' ',' ',
	['a', producer]))
    end

    # Get actor(s).
    actor = row[inds[:actor]]
    if actor && actor.length > 0
      record.append(MARC::DataField.new(
	'511','1',' ',
	['a', actor]))
    end

    # Get studio
    studio = row[inds[:studio]]
    if studio && studio.length > 0
      record.append(MARC::DataField.new(
	'710','2',' ',
	['a', studio]))
    end

    # Get format (and optional regions, layers, and screen ratio).
    format = row[inds[:format]]
    if format && format.length > 0
      region = row[inds[:region]]
      if region && region.length > 0
	format += '; ' + region
      end
      layersind = inds[:layers]
      if layersind
	layers = row[layersind]
	if layers && layers.length > 0 && layers != 'N/A'
	  format += '; ' + layers
	end
      end
      ratioind = inds[:ratio]
      if ratioind
	ratio = row[ratioind]
	if ratio && ratio.length > 0
	  format += '; ' + ratio
	end
      end
      record.append(MARC::DataField.new(
	'538',' ',' ',
	['a', format]))
    end

    # Get plot (present only for Windows-produced CSV files)
    plotind = inds[:plot]
    if plotind
      plot = row[plotind]
      if plot && plot.length > 0
	record.append(MARC::DataField.new(
	  '520',' ',' ',
	  ['a', plot]))
      end
    end

    # Get special features (present only for Windows-produced CSV files)
    extraind = inds[:extras]
    if extraind
      extra = row[extraind]
      if extra && extra.length > 0
	record.append(MARC::DataField.new(
	  '500',' ',' ',
	  ['a', 'Extra features: ' + extra]))
      end
    end

    # Get trailer URLS (present only for Windows-produced CSV files)
    trailerind = inds[:trailer]
    if trailerind
      trailer = row[trailerind]
      if trailer && trailer.length > 0
	trailers = trailer.split(/\s*;\s*/)
	trailers.each do |t|
	  record.append(MARC::DataField.new(
	    '856','4',' ',
	    ['u', t],
	    ['y', 'Trailer video']))
	end
      end
    end

    # Get edition.
    editionind = inds[:edition]
    if editionind
      edition = row[editionind]
      if edition && edition.length > 0
	record.append(MARC::DataField.new(
	  '250',' ',' ',
	  ['a', edition]))
      end
    end

    # Get audience rating.
    ratingind = inds[:rating]
    if ratingind
      rating = row[ratingind]
      if rating && rating.length > 0
	record.append(MARC::DataField.new(
	  '521','8',' ',
	  ['a', 'MPAA rating: ' + rating]))
      end
    end

    # Try to determine genre for spine tag. See comment in shortgenre
    # above for a discussion about why this is so error-prone.
    if genre
      genre3 = shortgenre(genres, windows)
    end

    # Fabricate a call number.
    call = ('DVD ' + genre3 + ' ' + title3).strip

    # Convert date from Mon DD, YYYY to YYYY-MM-DD
    datestr = convertdate(row[inds[:date]])

    # Append Koha holding information.
    record.append(MARC::DataField.new(
      '952', ' ',  ' ',
      ['8', 'A'],
      ['a', 'RCML'],
      ['b', 'RCML'],
      ['c', 'DVD'],
      ['d', datestr],
      ['o', call],
      ['y', 'DVD']))
    writer.write(record)
  end
end

# Attempt to fetch a MARC record for a given ISBN from a
# Z39.50 server.  If found, return it as a MARC::Record object;
# otherwise return nil.

def get_z3950(isbn)
  servers = [
    [ 'lx2.loc.gov',		   210,	'LCDB' ],
    [ 'catalog.nypl.org',	   210,	'INNOPAC' ],
    [ 'catalog.dallaslibrary.org', 210,	'PAC' ]
  ]

  servers.each do |rec|
    host = rec[0]
    port = rec[1]
    db = rec[2]

    begin
      ZOOM::Connection.open(host, port) do |conn|
	conn.database_name = db
	conn.preferred_record_syntax = 'USMARC'
	rset = conn.search("@attr 1=7 #{isbn}")
	if rset[0]
	  puts "ISBN #{isbn} found at #{host}"
	  return MARC::Record.new_from_marc(rset[0].raw)
	else
	  puts "ISBN #{isbn} not found at #{host}"
	end
      end
    rescue => exc
      puts "Exception trying to search #{host}: #{exc}"
    end
  end
  return nil
end

dryrun = false		# Can be set to true by -n option
overwrite = false	# Can be set to true by -o option
use_z3950 = false	# Can be set to true by -z option
windows = false		# Can be set to true by -w option
col_sep = ','		# Can be set to semicolon by -z option

book = true		# true if book catalog, false if movie catalog
first = true		# true if reading first row in CSV file

# Check for options before file arguments.
nopts = 0
ARGV.each do |arg|
  if arg == '-n'
    dryrun = true
    nopts += 1
  elsif arg == '-o'
    overwrite = true
    nopts += 1
  elsif arg == '-z'
    use_z3950 = true
    nopts += 1
  elsif arg == '-w'
    windows = true
    nopts += 1
  elsif arg == '-s'
    col_sep = ';'
    nopts += 1
  else
    break
  end
end
ARGV.shift(nopts)

# Check arguments. First is input file.  Second is output file.
if ARGV.length < 2
   puts "usage: clz2marc.rb [-n] [-o] inputfile.csv outputfile.marc"
   puts "  -n : don't write outfile, just print records from inputfile.csv"
   puts "  -o : overwrite existing output file"
   puts "  -z : use Z39.50 servers to fetch bib record"
   puts "  -s : CSV file uses semicolon separator instead of comma"
   puts "  -w : CSV file was produced by Collectorz Windows app"
   exit 1
end

input_file = ARGV[0]
output_file = ARGV[1]

unless dryrun
  if !overwrite && File.exist?(output_file)
    puts "#{output_file} exists; will not overwrite."
    exit 1
  end
  puts("Writing #{output_file} using utf-8 encoding")
  writer = MARC::Writer.new(output_file)
end

# Create a CSV file object, telling it the column separator character.
f = File.open(input_file, "r")
unless f
  puts "Unable to open #{input_file}"
  exit 1
end

csv = CSV.new(f, col_sep: col_sep)
unless csv
  puts "Unable to create a CSV object for #{input_file}"
  exit 1
end

csv.each do |row|
  # The first row contains column headers, from which we determine
  # whether we're reading a book catalog or a movie catalog.
  if first
    if row.index('Director')
      book = false
      columns = windows ? movie_columns_windows : movie_columns
    else
      book = true
      columns = windows ? book_columns_windows : book_columns
    end
    columns.each do |key, value|
      ind = row.index(value)
      if ind
	inds[key] = ind
      else
	puts "#{value} not seen in first row"
	exit 1
      end
    end
    first = false
  else
    if book
      convertbook(row, inds, dryrun, use_z3950, windows, locs, writer)
    else
      convertmovie(row, inds, dryrun, windows, writer)
    end
  end
end

unless dryrun
  writer.close()
end
