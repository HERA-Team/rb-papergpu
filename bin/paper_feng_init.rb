#!/usr/bin/env ruby

# paper_feng_init.rb - Script to initialize PAPER F engine(s)

require 'rubygems'
require 'optparse'
require 'papergpu/roach2_fengine'
#require 'redis'
#require 'hashpipe/keys'
#
#include Hashpipe::RedisKeys


OPTS = {
  :redishost => 'redishost',
  :verbose   => true
}

OP = OptionParser.new do |op|
  op.program_name = File.basename($0)

  op.banner = "Usage: #{op.program_name} [OPTIONS] HOST[:FID] ..."
  op.separator('')
  op.separator('Initialize 32-input ROACH2 F Engine(s).')
  op.separator('If HOST is "pfN", then the ":FID" suffix can be omitted')
  op.separator('and FID will be N-1 (e.g. "pf1" will get FID=0).');
  op.separator('')
  op.separator('Options:')
  op.on('-r', '--redishost=NAME',
        "Host running redis-server [#{OPTS[:redishost]}]") do |o|
    OPTS[:redishost] = o
  end
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

# Parse host and FIDs from command line arguments
host_fids = ARGV.map do |hf|
  host, fid = hf.split(':')
  if fid
    # Use given FID
    fid = Integer(fid)
  else
    # Parse fid from pfN host
    fid = $1 if host =~ /^pf(\d+)$/
    if fid.nil?
      puts "Cannot determine FID from '#{hf}'"
      exit 1
    end
    fid = Integer(fid) - 1
  end
  puts "initializing #{host} as FID #{fid}" if OPTS[:verbose]
  [host, fid]
end

# Create list of FIDs
fids = host_fids.map {|host, fid| fid}

# Create Roach2Fengine objects and set FID registers
fe_fids = host_fids.map do |host, fid|
  puts "connecting to #{host}" if OPTS[:verbose]
  pf = Paper::Roach2Fengine.new(host)
  # Verify that device is already programmed
  if ! pf.programmed?
    puts "error: #{host} is not programmed"
    exit 1
  end
  # Verify that given design appears to be the roach2_fengine
  if ! pf.listdev.grep('eth_0_xip').any?
    puts "error: #{host} is not programmed with an roach2_fengine design."
    exit 1
  end
  puts "setting #{host} FID to #{fid}" if OPTS[:verbose]
  pf.fid = fid
  [pf, fid]
end

# Setup details ofr 10 GbE cores
sw_mac_base = 0x0202_0a0a_0a00
sw_ip_base  =      0x0a0a_0a00

sw_arp_table = NArray.int(2,256).indgen!.div!(2).add!(sw_mac_base&0xffff_ffff)
sw_arp_table[0,nil] = (sw_mac_base >> 32)

gpu_mac_base = 0x0202_c0a8_0000
gpu_ip_base  =      0x0a0a_0000

fe_fids.each do |fe, fid|
  # Setup switch 10 GbE cores
  4.times do |i|
    puts "configuring #{fe.host}:eth_#{1}_sw" if OPTS[:verbose]
    eth_sw = fe.send("eth_#{i}_sw")
    # IP
    ip = sw_ip_base + 32 + 8*i + fid
    printf("  IP  %08x\n", ip) if OPTS[:verbose]
    eth_sw.ip = ip
    # MAC
    mac = sw_mac_base + 32 + 8*i + fid
    printf("  MAC %012x\n", mac) if OPTS[:verbose]
    eth_sw.mac = mac
    # Populate ARP table
    puts "  ARP table" if OPTS[:verbose]
    eth_sw.set(0x0c00, sw_arp_table)
  end

  # Setup gpu 10 GbE cores and xip registers
  4.times do |i|
    puts "configuring #{fe.host}:eth_#{1}_gpu" if OPTS[:verbose]
    eth_gpu = fe.send("eth_#{i}_gpu")

    # IP
    ip = gpu_ip_base + 512 + 256*i + fid + 1
    printf("  IP  %08x\n", ip) if OPTS[:verbose]
    eth_gpu.ip = ip
    # MAC
    mac = gpu_mac_base + 512 + 256*i + fid + 1
    printf("  MAC %012x\n", mac) if OPTS[:verbose]
    eth_gpu.mac = mac
    ## Populate ARP table
    #puts "  ARP table" if OPTS[:verbose]
    #eth_sw.set(0x0c00, sw_arp_table)

    # X engine is hostname "px#{fid-1}-#{i+2}"
    # (e.g. for FID 0, eth_0_gpu is connected to "px1-2"
    xip = IPAddr.new(Addrinfo.ip("px#{fid+1}-#{i+2}").ip_address).to_i
    fe.send("eth_#{i}_xip=", xip)
  end
end
