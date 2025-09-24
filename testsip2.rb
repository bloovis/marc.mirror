#!/usr/bin/env ruby

# This script tests the SIP2 functionality in Koha.  I use it to test
# that my sip2patron plugin for Koha is working correctly, but it
# could be used for any SIP2 setup.
#
# The script takes the following parameters:
# host - the hostname of the Koha server to test
# port - the port number of Koha's SIP2 server (typically 6001)
# library - the name of the Koha instance
# sip2 user - the name of the SIP2 user, used to log in
# sip2 password - the password of the SIP2 user
# patron - the username of the patron to check for validity
# patron password - the password of the patron being checked
# patron barcode - the barcode of the patron being checked

require 'ruby_expect'

def usage(msg)
  puts msg
  puts 'usage: testsip2.rb host port library sip2user sip2password patron patronpassword patronbarcode'
  exit 1
end

# Calculate the SIP2 checksum of the string
def checksum(s)
  sum = 0
  s.each_byte do |c|
    sum += c.ord
  end
  sum = sum & 0xffff
  sprintf("%4.4X", -sum & 0xffff)
end

usage('host not specified') unless host = ARGV[0]
usage('port not specified') unless port = ARGV[1]
usage('library code not specified') unless lib = ARGV[2]
usage('sip2 user not specified') unless sip2user = ARGV[3]
usage('sip2 user password not specified') unless sip2password = ARGV[4]
usage('patron not specified') unless patron = ARGV[5]
usage('patron password not specified') unless patronpassword = ARGV[6]
usage('patron barcode not specified') unless barcode = ARGV[7]

$logger = ::Logger.new($stdout)
$logger.level = ::Logger::DEBUG # was WARN

exp = RubyExpect::Expect.spawn("telnet #{host} #{port}", {logger: $logger})

exp.procedure do
  # Expect each of the following
  each do
    expect /Trying .*\.\.\./ do
    end

    expect /Connected to #{host}/ do
    end

    # login message
    cmd93 = "9300CN#{sip2user}|CO#{sip2password}|CP#{lib}|"
    #cmd93 = "9300CN#{sip2user}|CO#{sip2password}|AY0AZ"	# AY = sequence #, AZ = checksum
    #cmd93 += checksum(cmd93)
    expect /Escape character is/ do
      send cmd93
    end

    # telnet echoes back everything we send, so we have to expect that.
    expect cmd93 do
    end

    # check a patron
    cmd23 = "2300120060101    084235AO#{lib}|AA#{patron}|ACsip_01|AD#{patronpassword}|"
    expect /941/ do
      # wait a bit to test simultaneous connections
      sleep 3

      send cmd23
    end

    # telnet echoes back everything we send, so we have to expect that.
    expect cmd23 do
    end

    expect /24.*\|AA#{barcode}\|BLY\|CQY\|.*AFGreetings from Koha.*\|AO#{lib}\|/i do
      send "\r"
    end

    expect /Connection closed by foreign host/ do
    end
  end
end
