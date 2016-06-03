#!/usr/bin/env ruby

# paper_lst_trig.rb - script to start PAPER correlator so that integrations
# coincide with the same LST periods.

require 'rubygems'
require 'optparse'
require 'redis'
require 'hashpipe/keys'
require 'miriad'

include Hashpipe::RedisKeys


# Computes mcounts per second.  chan_per_pkt must be a factor of 1024 for
# correct results.

def mcnts_per_second(spectra_per_mcnt=8)
  mcnt_per_spectrum = Rational(1, spectra_per_mcnt)

  samples_per_spectrum = 2048
  spectra_per_sample = Rational(1, samples_per_spectrum)

  samples_per_second = 200e6

  mcnts_per_sec = (mcnt_per_spectrum * spectra_per_sample * samples_per_second)
end
#p mcnts_per_second; exit

# returns an array of allowed integration start lstimes
# based on a start time of lst=0, and incrementing in
# integration time steps
def get_st_vectors(inttime)
  sday = 23.9344699 # length of sidereal day in solar hours
  nints_per_sday = ((sday*3600)/inttime).floor #inttime is in seconds
  # an array containing the possible integration start lstimes for a day
  int_starts = NArray.float(nints_per_sday).indgen!.mul!(24.0/nints_per_sday) #seriously?!
end

# Computes the utc time of the nearest allowed integration start to an
# allowed set of lstimes.
# I.e., You want an observation starting at time [utc_start]. This
# function will return a closely valued time, which has integrations
# which lie on the regular lst starts permitted by get_st_vectors()
# inttime is the integration time, and must be given precisely.
# [now] is a DateTime object, and can be used to specify the day of observation.
# (by default it is DateTime.now, i.e., today).
def closest_int_start(inttime,utc_start,longitude,now=DateTime.now)
  target_utc = DateTime.new(now.year,now.month,now.day,utc_start)
  puts "Target UTC: " + target_utc.to_time.to_s
  target_lst = target_utc.last(longitude=longitude)
  puts "Target LST: " + target_lst.to_hmsstr 
  puts "Target LST: " + target_lst.to_f.to_s
  # get the array of allowed integration start times, and see which
  # best matches our target. For now let's force the start time to be
  # before the observation time. The minimum difference between the
  # our target times and the allowed times is the amount we need to shift
  # our start time.
  st = get_st_vectors(inttime)
  offset = (st.sbt!(target_lst.to_f)).mul!(3600)
  nearest_offset = offset[offset<=0].max * (23.9344/24.0)#max because values are negative
  puts "Closest allowed start time residual: " + (nearest_offset/3600.0).to_s
  # offset the target utc start time by the right number of seconds
  puts "Requested time " + target_utc.to_time.to_s
  puts "granted time " + (target_utc.to_time+nearest_offset).to_s
  puts "granted time " + (target_utc.to_time+nearest_offset).to_f.to_s
  start_time = (target_utc.to_time + nearest_offset).to_f
end

# input current sync_time and target utc start time in seconds, along with
# the minimum unit at which we can start an integration.
# Return the target mcnt to start on
def closest_mcnt(sync_time, utc, mcnt_unit)
  # offset in seconds of start time relative to sync_time
  offset = utc-sync_time
  puts "offset from feng sync to start time (seconds):" + offset.to_s
  puts "offset from feng sync to start time (mcnts):" + ((mcnts_per_second()*offset)/mcnt_unit).to_s
  mcnt = (mcnts_per_second() * offset).floor
  mcnt -= mcnt % mcnt_unit
end
  

OPTS = {
  :num_xbox  => 8,
  :num_inst  => 4,
  :intcount  => 2048,
  :intdelay  => 10,
  :longitude => 18.4239,
  :inttime   => 10.73741824,
  :mcnt_gran => 64,
  :utc       => 16.0,
  :server    => 'redishost',
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
  op.on('-n', '--intcount=N', Integer,
        "GPU blocks per integration [#{OPTS[:intcount]}]") do |o|
    # TODO Put reasonable bounds on it
    OPTS[:intcount] = o
  end
  op.on('-i', '--numinst=N', Integer,
        "Number of instances per X host [#{OPTS[:num_inst]}]") do |o|
    OPTS[:num_inst] = o
  end
  op.on('-s', '--server=NAME',
        "Host running redis-server [#{OPTS[:server]}]") do |o|
    OPTS[:server] = o
  end
  op.on('-x', '--numxhost=N', Integer,
        "Number of X hosts [#{OPTS[:num_xbox]}]") do |o|
    OPTS[:num_inst] = o
  end
  op.on('-l', '--longitude=N', Float,
        "Longitude of array [#{OPTS[:longitude]}]") do |o|
    OPTS[:longitude] = o
  end
  op.on('-t', '--utc=N', Float,
        "Target UTC observation start time [#{OPTS[:utc]}]") do |o|
    OPTS[:utc] = o
  end
  op.on('-N', '--inttime=N', Float,
        "Integration time in seconds (should be precise!) [#{OPTS[:inttime]}]") do |o|
    OPTS[:inttime] = o
  end
  op.on('-g', '--mcnt_gran=N', Integer,
        "MCNT granularity that can be used to specify an MCNT start count [#{OPTS[:mcnt_gran]}]") do |o|
    OPTS[:mcnt_gran] = o
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

# Create status keys for px1/0 to px#{num_xbox}/#{num_inst-1}
xboxes = (1..OPTS[:num_xbox]).to_a
insts  = (0...OPTS[:num_inst]).to_a
STATUS_KEYS = xboxes.product(insts).map {|x,i| status_key("px#{x}", i)}
#p STATUS_KEYS; exit

# Function to get values for Hashpipe status key +skey+ from all Redis keys +hkeys+
# hashes in Redis.
def get_hashpipe_status_values(redis, skey, *hkeys)
  hkeys.flatten.map! do |hk|
    sval = redis.hget(hk, skey)
    block_given? ? yield(sval) : sval
  end
end

def start(redis)
  gpumcnts = get_hashpipe_status_values(redis, 'GPUMCNT', STATUS_KEYS)
  #p gpumcnts
  gpumcnts.compact!
  #p gpumcnts

  if gpumcnts.empty?
    puts "#{File.basename($0)}: no GPUMCNT values found, cannot start"
    return
  end

  if gpumcnts.length != STATUS_KEYS.length
    missing = STATUS_KEYS.length - gpumcnts.length
    puts "#{File.basename($0)}: warning: missing GPUMCNT for #{missing} X engine instances"
  end

  # get target start time based on user input parameters
  start_time = closest_int_start(OPTS[:inttime],OPTS[:utc],OPTS[:longitude])
  # get closest possible start MCNT
  roachf_sync_time = redis['roachf_init_time'].to_i
  target_mcnt = closest_mcnt(roachf_sync_time, start_time, OPTS[:mcnt_gran])
  #puts "Target start MCNT: " + target_mcnt.to_s
  t = roachf_sync_time + (target_mcnt/mcnts_per_second().to_f)
  start_date = Time.at(t).to_datetime
  start_lst = start_date.last(longitude=OPTS[:longitude])
  st = get_st_vectors(OPTS[:inttime])
  residual = st.sbt!(start_lst.to_f).abs.min * 3600 
  puts "### ACTUAL START TIME ###" + start_lst.to_s
  puts "### Residual vs st vector ### " + residual.to_s

  start_msg = "INTSYNC=#{target_mcnt}\nINTCOUNT=#{OPTS[:intcount]}\nINTSTAT=start"

  redis.publish(bcast_set_channel, start_msg)
end

def stop(redis)
  intstats = get_hashpipe_status_values(redis, 'INTSTAT', STATUS_KEYS)
  #p intstats
  intstats.compact!
  #p intstats

  if intstats.empty?
    puts "#{File.basename($0)}: no INTSTAT values found, nothing to stop"
    return
  end

  if intstats.length != STATUS_KEYS.length
    missing = STATUS_KEYS.length - intstats.length
    puts "#{File.basename($0)}: warning: missing INTSTAT for #{missing} X engine instances"
  end

  stop_msg = "INTSTAT=stop"

  redis.publish(bcast_set_channel, stop_msg)
end

def test(redis)
  roachf_sync_time = redis['roachf_init_time'].to_i
  now=DateTime.now
  8.times do |i|
    st = get_st_vectors(OPTS[:inttime])
    # get target start time based on user input parameters
    start_time = closest_int_start(OPTS[:inttime],OPTS[:utc],OPTS[:longitude],now=now)
    #puts "Roach sync time is: " + roachf_sync_time.to_s
    # get closest possible start MCNT
    target_mcnt = closest_mcnt(roachf_sync_time, start_time, OPTS[:mcnt_gran])
    #puts "Target start MCNT: " + target_mcnt.to_s
    t = roachf_sync_time + (target_mcnt/mcnts_per_second().to_f)
    puts t.to_f
    start_date = Time.at(t).to_datetime
    start_lst = start_date.last(longitude=OPTS[:longitude])
    residual = st.sbt!(start_lst.to_f).abs.min * 3600 
    puts "### ACTUAL START TIME ###" + start_lst.to_s
    puts "### Residual vs st vector ### " + residual.to_s
    now = now.next_day
  end
end

redis = Redis.new(:host => OPTS[:server])
puts mcnts_per_second()

case cmd
when 'start'; start(redis)
when 'stop' ; stop(redis)
when 'test' ; test(redis)
else
  # Should never happen
  raise "Invalid command: '#{cmd}'"
end
