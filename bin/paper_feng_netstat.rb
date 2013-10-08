#!/usr/bin/env ruby

# bin/paper_feng_netstat.rb - Script to report netstatus of PAPER F engine(s)

require 'rubygems'
require 'optparse'
require 'ipaddr'
require 'papergpu/roach2_fengine'


OPTS = {
  :verbose   => false
}

OP = OptionParser.new do |op|
  op.program_name = File.basename($0)

  op.banner = "Usage: #{op.program_name} [OPTIONS] HOST ..."
  op.separator('')
  op.separator('Report on 10 GbE status of 32-input ROACH2 F Engine(s).')
  op.separator('')
  op.separator('Options:')
  op.on('-v', '--[no-]verbose', "Be verbose [#{OPTS[:verbose]}]") do |o|
    OPTS[:verbose] = o
  end
  op.separator('')
  op.on_tail('-h','--help','Show this message') do
    puts op.help
    exit
  end
end
OP.parse!
#p OPTS; exit

if ARGV.empty?
  puts OP.help
  exit
end

def dump_stat(fe)
  # For each switch ethernet interface, print address info
  4.times do |eth|
    e = fe.send("eth_#{eth}_sw")
    printf "%s:eth_%d_sw : ", fe.host, eth
    printf "MAC:%s, IP:%s\n",
      [e.mac].pack('Q>').unpack('C*')[2,6].map!{|i| '%02x' % i}.join('-'),
      IPAddr.new(e.ip, Socket::AF_INET)
  end

  # For each switch ethernet interface, print status info
  4.times do |eth|
    printf "%s:eth_%d_sw : ", fe.host, eth
    printf "bframes:%-3d ", fe.send("eth_#{eth}_sw_bframes")
    printf "oruns:%-3d ", fe.send("eth_#{eth}_sw_oruns")
    printf "oflows:%-3d ", fe.send("eth_#{eth}_sw_oflows")
    status = fe.send("eth_#{eth}_sw_status")
    printf "status: %cUP %cTX %cRX %s\n",
      status & 0x40 != 0 ? '+' : '-',
      status & 0x10 != 0 ? '+' : '-',
      status & 0x20 != 0 ? '+' : '-',
      status & 0x70 == 0x70 ? 'OK' : 'BAD'
  end

  # For each GPU ethernet interface, print address info
  4.times do |eth|
    e = fe.send("eth_#{eth}_gpu")
    printf "%s:eth_%d_gpu : ", fe.host, eth
    printf "MAC:%s, IP:%s\n",
      [e.mac].pack('Q>').unpack('C*')[2,6].map!{|i| '%02x' % i}.join('-'),
      IPAddr.new(e.ip, Socket::AF_INET)
  end

  # For each GPU ethernet interface, print status info
  4.times do |eth|
    printf "%s:eth_%s_gpu: ", fe.host, eth
    printf "xip:%-17s ", IPAddr.new(fe.send("eth_#{eth}_xip"), Socket::AF_INET)
    printf "oflows:%-3d ", fe.send("eth_#{eth}_gpu_oflows")
    status = fe.send("eth_#{eth}_gpu_status")
    printf "status: %cUP %cTX %cRX %s\n",
      status & 0x40 != 0 ? '+' : '-',
      status & 0x10 != 0 ? '+' : '-',
      status & 0x20 != 0 ? '+' : '-',
      status & 0x70 == 0x50 ? 'OK' : 'BAD'
  end
end

# Create Roach2Fengine objects
ARGV.each_with_index do |host, i|
  puts "connecting to #{host}" if OPTS[:verbose]
  fe = Paper::Roach2Fengine.new(host)

  # Verify that device is already programmed
  if ! fe.programmed?
    puts "error: #{host} is not programmed"
    exit 1
  end
  # Verify that given design appears to be the roach2_fengine
  if ! fe.listdev.grep('eth_0_xip').any?
    puts "error: #{host} is not programmed with an roach2_fengine design."
    exit 1
  end
  if OPTS[:verbose]
    # Display RCS revision info
    rcs = fe.rcs
    if rcs[:app].has_key? :rev
      app_rev = rcs[:app][:rev]
      lib_rev = rcs[:lib][:rev]
      puts "#{host} roach2_fengine app/lib revision #{app_rev}/#{lib_rev}"
    end
  end

  dump_stat(fe)
  puts unless i == ARGV.length-1
end

puts 'all done' if OPTS[:verbose]
