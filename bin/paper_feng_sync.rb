#!/usr/bin/env ruby

# paper_feng_sync.rb - Script to (re-)sync PAPER F engine(s)

require 'rubygems'
require 'optparse'
require 'papergpu/roach2_fengine'
require 'redis'

OPTS = {
  :redishost => 'redishost',
  :seed      => 0x11111111,
  :sync      => false,
  :noise     => false,
  :verbose   => false
}

OP = OptionParser.new do |op|
  op.program_name = File.basename($0)

  op.banner = "Usage: #{op.program_name} [OPTIONS] HOST ..."
  op.separator('')
  op.separator('Sync (or re-sync) 32-input ROACH2 F Engine(s).')
  op.separator('')
  op.separator('Options:')
  op.on('-r', '--redishost=NAME',
        "Host running redis-server [#{OPTS[:redishost]}]") do |o|
    OPTS[:redishost] = o
  end
  op.on('-n', '--[no-]noise', "Arm noise generator [#{OPTS[:noise]}]") do |o|
    OPTS[:noise] = o
  end
  op.on('-s', '--[no-]sync', "Arm sync generator [#{OPTS[:sync]}]") do |o|
    OPTS[:sync] = o
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

if ARGV.empty?
  puts OP.help
  exit
end

# Create Roach2Fengine objects
fes = ARGV.map do |host|
  puts "connecting to #{host}"
  fe = Paper::Roach2Fengine.new(host) rescue nil
  return nil unless fe
  # Verify that device is already programmed
  if ! fe.programmed?
    puts "error: #{host} is not programmed"
    return nil
  end
  # Verify that given design appears to be the roach2_fengine
  if ! fe.listdev.grep('eth_0_xip').any?
    puts "error: #{host} is not programmed with an roach2_fengine design."
    return nil
  end
  # Display RCS revision info
  rcs = fe.rcs
  if rcs[:app].has_key? :rev
    app_rev = rcs[:app][:rev]
    lib_rev = rcs[:lib][:rev]
    puts "#{host} roach2_fengine app/lib revision #{app_rev}/#{lib_rev}"
  end
  fe
end

# Compact fes (remove nils) in case any errors were encountered
fes.compact!
fe0 = fes[0]

# Arm sync generator
if OPTS[:sync]
  # Disable network transmission
  puts "disabling network transmission"
  fes.each do |fe|
    puts "  disabling #{fe.host} network transmission" if OPTS[:verbose]
    fe.eth_sw_en = 0
    fe.eth_gpu_en = 0
  end

  puts "arming sync generator(s)"
  # We are potentially doing a batch of F engines so we want to get the arm
  # signals delivered to all F engines as close as possible.  Because of this,
  # we perform the arming "manually" rather than using the #arm_sync method on
  # each F engine.
  fes.each {|fe| fe.wordwrite(:sync_arm, 0)}
# BEGIN WORKAROUND
#  This code would work if the 1 PPS signal were sync'd to real time (e.g. via
#  GPS), but in the basement of Evans Hall that is not the case.  So we loop on
#  the first F engine until its sync_count counter increments.
#  # Sleep until just after top of next second
#  sleep(1.1 - (Time.now.to_f % 1))
  sync_count = fe0.sync_count
  true while fe0.sync_count == sync_count
# END WORKAROUND
  # Arm all the F engines
  fes.each {|fe| fe.wordwrite(:sync_arm, 1)}
  fes.each {|fe| fe.wordwrite(:sync_arm, 0)}
  # Compute sync time
  sync_time = Time.now.to_i + 1
  # Sleep 1 second to wait for sync
  sleep 1
  # Store sync time in redis
  puts "storing sync time in redis on #{OPTS[:redishost]}"
  redis = Redis.new(:host => OPTS[:redishost])
  redis['roachf_init_time'] = sync_time

  # Reset network cores
  puts "resetting network interfaces"
  fes.each do |fe|
    puts "  resetting #{fe.host} network interfaces" if OPTS[:verbose]
    [0, 1, 0].each do |v|
      fe.eth_cnt_rst = v
      fe.eth_gpu_rst = v
      fe.eth_sw_rst = v
    end
  end

  # Enable network transmission
  puts "enable transmission to X engines"
  fes.each do |fe|
    puts "  enable #{fe.host} transmission to X engines" if OPTS[:verbose]
    fe.eth_gpu_en = 1
  end

  puts "enable transmission to switch"
  fes.each do |fe|
    puts "  enable #{fe.host} transmission to switch" if OPTS[:verbose]
    fe.eth_sw_en = 1
  end
end

# Arm noise generators
if OPTS[:noise]
  puts "seeding noise generators"
  fes.each do |fe|
    fe.seed_0 = OPTS[:seed]
    fe.seed_1 = OPTS[:seed]
    fe.seed_2 = OPTS[:seed]
    fe.seed_3 = OPTS[:seed]
  end

  puts "arming noise generator(s)"
  sync_count = fe0.sync_count
  true while fe0.sync_count == sync_count
  fes.each {|fe| fe.arm_noise}
end

puts 'all done'
