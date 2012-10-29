#!/usr/bin/env ruby

# paper_ctl.rb - Script to control PAPER correlator (basically start/stop
#                integrations).

require 'rubygems'
require 'optparse'
require 'redis'
require 'hashpipe/keys'

include Hashpipe::RedisKeys


# Computes mcounts per second.  chan_per_pkt must be a factor of 1024 for
# correct results.  Rounds up to the nearest multiple of 2048.
def mcnts_per_second(chan_per_pkt=64)
  bytes_per_pkt = 8192
  inputs_per_pkt = 8
  spectra_per_mcnt = bytes_per_pkt/inputs_per_pkt/chan_per_pkt
  mcnt_per_spectrum = Rational(1, spectra_per_mcnt)

  samples_per_spectrum = 2048
  spectra_per_sample = Rational(1, samples_per_spectrum)

  samples_per_second = 200e6

  (mcnt_per_spectrum * spectra_per_sample * samples_per_second + 2047).to_i / 2048 * 2048
end
#p mcnts_per_second; exit


OPTS = {
  :intcount => 2048,
  :intdelay => 15,
  :server   => 'redishost',
}

OP = OptionParser.new do |op|
  op.program_name = File.basename($0)

  op.banner = "Usage: #{op.program_name} [OPTIONS] {start|stop}"
  op.separator('')
  op.separator('Start and stop PAPER correlator integrations')
  op.separator('')
  op.separator('Options:')
  op.on('-d', '--delay=SECONDS', Integer,
        "Delay before starting [#{OPTS[:intdelay]}]") do |o|
    # TODO Put reasonable bounds on it
    OPTS[:intdelay] = o
  end
  op.on('-n', '--intcount=MCNTS', Integer,
        "MCOUNTs per integration [#{OPTS[:intcount]}]") do |o|
    # TODO Put reasonable bounds on it
    OPTS[:intcount] = o
  end
  #op.on('-i', '--instances=I[,...]', Array,
  #      "Instances to gateway [#{OPTS[:instance_ids]}]") do |o|
  #  OPTS[:instance_ids] = o.map {|s| Integer(s) rescue 0}
  #  OPTS[:instance_ids].uniq!
  #end
  op.on('-s', '--server=NAME',
        "Host running redis-server [#{OPTS[:server]}]") do |o|
    OPTS[:server] = o
  end
  op.separator('')
  op.on_tail('-h','--help','Show this message') do
    puts op.help
    exit
  end
end
OP.parse!
#p OPTS; exit

cmd = ARGV.shift
if cmd != 'start' && cmd != 'stop' && cmd != 'test'
  puts OP.help
  exit 1
end

# Create status keys for px1/0 to px8/1
STATUS_KEYS = (1..8).to_a.product([0,1]).map {|x,i| status_key("px#{x}", i)}

# Function to get values for Hashpipe status key +skey+ from all Redis keys +hkeys+
# hashes in Redis.
def get_hashpipe_status_values(redis, skey, *hkeys)
  hkeys.flatten.map! do |hk|
    sval = redis.hget(hk, skey)
    block_given? ? yield(sval) : sval
  end
end

redis = Redis.new(:host => 'paper.paper.pvt')

gpumcnts = get_hashpipe_status_values(redis, 'GPUMCNT', STATUS_KEYS)
#p gpumcnts
gpumcnts.compact!
#p gpumcnts

if gpumcnts.length != STATUS_KEYS.length
  missing = STATUS_KEYS.length - gpumcnts.length
  puts "Warning: missing GPUMCNT for #{missing} X engine instances"
end

# Convert to ints
gpumcnts.map! {|s| s.to_i(0)}
#p gpumcnts

min_gpumcnt, max_gpumcnt = gpumcnts.minmax
#p [min_gpumcnt, max_gpumcnt]; exit

intdelay_mcnts = (((OPTS[:intdelay] * mcnts_per_second) + 2047).floor / 2048) * 2048

intsync = max_gpumcnt + intdelay_mcnts

puts "Min GPUMCNT is %d" % min_gpumcnt
puts "Max GPUMCNT is %d  (range %d)" % [max_gpumcnt, max_gpumcnt - min_gpumcnt]
puts "Delay  MCNT is %d" % intdelay_mcnts
puts "Sync   MCNT is %d" % intsync

#puts(<<-END) if cmd == 'start'
redis.publish(bcast_set_channel, <<-END) if cmd == 'start'
INTSYNC=#{intsync}
INTCOUNT=#{OPTS[:intcount]}
INTSTAT=start
END
