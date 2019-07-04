#!/usr/bin/env ruby

# This script does a quasi-diff on two CSV files containing dumps
# of book catalogs from collectorz.com.  It outputs two new CSV files:
# - One containing all the records from the first file that are not in the second
# - One containing all the records from the second file that are not the first

require 'csv'

overwrite = false	# Can be set to true by -o option
windows = false		# Can be set to true by -w option
col_sep = ','		# Can be set to semicolon by -z option
book = true		# true if book catalog, false if movie catalog
first = true		# true if reading first row in CSV file

# Check for options before file arguments.
nopts = 0
ARGV.each do |arg|
  if arg == '-o'
    overwrite = true
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

# Check arguments. First two are input files.  Second two are output files.
if ARGV.length < 4
   puts "usage: diffclz.rb [-n] [-o] inputfile1.csv inputfile2.csv outputfile1.csv outputfile2.csv"
   puts "  -o : overwrite existing output file"
   puts "  -s : CSV file uses semicolon separator instead of comma"
   puts "  -w : CSV file was produced by Collectorz Windows app"
   exit 1
end

input_file1 = ARGV[0]
input_file2 = ARGV[1]
output_file1 = ARGV[2]
output_file2 = ARGV[3]

if !overwrite && File.exist?(output_file1)
  puts "#{output_file1} exists; will not overwrite."
  exit 1
end
if !overwrite && File.exist?(output_file2)
  puts "#{output_file2} exists; will not overwrite."
  exit 1
end

# Create CSV file objects, telling it the column separator character.
f1 = File.open(input_file1, "r")
unless f1
  puts "Unable to open #{input_file1}"
  exit 1
end
csv1 = CSV.new(f1, col_sep: col_sep)
unless csv1
  puts "Unable to create a CSV object for #{input_file1}"
  exit 1
end

f2 = File.open(input_file2, "r")
unless f2
  puts "Unable to open #{input_file2}"
  exit 1
end
csv2 = CSV.new(f2, col_sep: col_sep)
unless csv2
  puts "Unable to create a CSV object for #{input_file2}"
  exit 1
end

rows1 = {}
rows2 = {}
header1 = ""
header2 = ""
ind_ind = 0	# index of "Index" field in a row

first = true
csv1.each do |row|
  # The first row contains column headers, from which we determine
  # whether we're reading a book catalog or a movie catalog.
  if first
    ind_ind = row.index('Index')
    unless ind_ind
      puts 'Index not seen in first row'
      exit 1 
    end
    first = false
    header1 = row.to_csv
  else
    ind = row[ind_ind]
    rows1[ind] = row.to_csv
  end
end

first = true
csv2.each do |row|
  # The first row contains column headers, from which we determine
  # whether we're reading a book catalog or a movie catalog.
  if first
    ind_ind = row.index('Index')
    unless ind_ind
      puts 'Index not seen in first row'
      exit 1 
    end
    first = false
    header2 = row.to_csv
  else
    ind = row[ind_ind]
    rows2[ind] = row.to_csv
  end
end

of1 = File.open(output_file1, "w")
of1.write(header1)
rows1.each do |ind, row|
  unless rows2[ind]
    of1.write(row)
  end
end
of1.close

of2 = File.open(output_file2, "w")
of2.write(header2)
rows2.each do |ind, row|
  unless rows1[ind]
    of2.write(row)
  end
end
of2.close
