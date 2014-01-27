#!/usr/bin/env ruby

# Check papergpu hashpipe status buffers in redis for various anomalies.
# Prints message about all checks and ecits with an error code if any check
# detected a problem.
#
# Checks include:
#
# * Do all status buffers exist in redis
# * Do all status buffers show the same number of OUTDUMPS
# * Do all status buffers show reasonable values for GPUGBPS
#
# Exit status indicates results:
#
# * 0 OK status unchanged from last time
# * 1 Status changed since last time
# * 2 BAD status unchanged from last time
#
# Note that an exit code of 1 can mean:
#
# * OK changed to BAD
# * BAD changed to OK
# * BAD changed to a different BAD

require 'rubygems'
require 'optparse'
require 'stringio'
require 'redis'
require 'mail'

OPTS = {
  :server       => 'redishost',
  :mail_to      => nil,
  :mail_bcc     => nil,
  :force        => false,
  :delete       => false
}

OP = OptionParser.new do |op|
  op.program_name = File.basename($0)

  op.banner = "Usage: #{op.program_name} [OPTIONS]"
  op.separator('')
  op.separator(<<-END.gsub(/^\s+/,''))
    Check PAPER correlator status in redis.  Errors are reported only if they
    have changed since the last check (or -f is given).  If -t or -b is used,
    output is email-only and not to stdout.  The -d option only deletes the
    last status from th Redis cache.
    END
  op.separator('')
  op.separator('Options:')
  op.on('-b', '--bcc=ADDR[,ADDR]',
        "BCC addresses [none]") do |o|
    OPTS[:mail_bcc] = o
  end
  op.on('-d', '--[no-]delete',
        "Delete status from Redis [#{OPTS[:delete]}]") do |o|
    OPTS[:delete] = o
  end
  op.on('-f', '--[no-]force',
        "Always output message [#{OPTS[:force]}]") do |o|
    OPTS[:force] = o
  end
  op.on('-s', '--server=NAME',
        "Host running Redis server [#{OPTS[:server]}]") do |o|
    OPTS[:server] = o
  end
  op.on('-t', '--to=ADDR[,ADDR]',
        "To addresses [none]") do |o|
    OPTS[:mail_to] = o
  end
  op.separator('')
  op.on_tail('-h','--help','Show this message') do
    puts op.help
    exit
  end
end
OP.parse!

# Create Redis object
REDIS = Redis.new(host: OPTS[:server]) rescue nil

if REDIS.nil?
  STDERR.puts "Could not connect to redis."
  exit 1
end

# Our Redis key
KEY = 'paper_redis_monitor://status'

# If deleting, delete and exit
if OPTS[:delete]
  REDIS.del(KEY)
  exit 0
end

msgio = StringIO.new
$stdout = msgio

status = 0

KEYS = {}
INSTANCES = []

for x in 1..8
  for j in 0..3
    inst = "px#{x}/#{j}"
    INSTANCES << inst
    KEYS[inst] = "hashpipe://#{inst}/status"
  end
end

def get_status_values(status_key, conv=:to_s)
  Hash[
    INSTANCES.map do |i|
      s = REDIS.hget(KEYS[i], status_key)
      val = s.nil? ? nil : s.send(conv) rescue nil
      [i, val]
    end
  ]
end

def check_outdumps
  status = 0

  # Get all outdump values
  outdumps = get_status_values('OUTDUMPS', :to_i)

  # Find missing ones
  missing_outdumps = outdumps.find_all {|i, v| v.nil?}

  # Output message about any missing ones
  if missing_outdumps.empty?
    puts "Got OUTDUMPS for all X engine instances"
  else
    missing_outdumps.each do |i, val|
      status += 1
      puts "Missing OUTDUMPS for X engine instance #{i}"
    end
  end

  # Find max OUTDUMPS
  max_outdumps = outdumps.values.compact.max

  if max_outdumps.nil?
    puts "No OUTDUMPS values found"
  else
    # Find bad OUTDUMPS (TODO Compare with calculated OUTDUMPS value?)
    bad_outdumps = outdumps.find_all {|i, v| v < max_outdumps - 1}

    # Output message about any bad outdump values
    if bad_outdumps.empty?
      puts "OUTDUMPS for present X engine instances all match"
    else
      bad_outdumps.each do |i, val|
        status += 1
        puts "Bad OUTDUMPS value for X engine instance #{i}"
      end
    end
  end

  puts

  status
end

def check_gpugbps
  status = 0

  # Get all gpugbps values
  gpugbps = get_status_values('GPUGBPS', :to_f)

  # Find missing ones
  missing_gpugbps = gpugbps.find_all {|i, v| v.nil?}

  # Output message about any missing ones
  if missing_gpugbps.empty?
    puts "Got GPUGBPS for all X engine instances"
  else
    missing_gpugbps.each do |i, val|
      status += 1
      puts "Missing GPUGBPS for X engine instance #{i}"
    end
  end

  # Find non-nil GPUGBPS
  present_gpugbps = gpugbps.find_all {|i, v| !v.nil?}

  if present_gpugbps.empty?
    puts "No GPUGBPS values found"
  else
    # Find bad GPUGBPS
    bad_gpugbps = present_gpugbps.find_all {|i, v| !((30..100) === v)}

    # Output message about any bad gpugbps values
    if bad_gpugbps.empty?
      puts "GPUGBPS for present X engine instances all in range"
    else
      bad_gpugbps.each do |i, val|
        status += 1
        printf "Bad GPUGBPS value (%.1f) for X engine instance %s\n", val, i
      end
    end
  end

  puts

  status
end

def send_message(status, opts)
  to = opts[:mail_to]
  bcc = opts[:mail_bcc]
  if to || bcc
    subject = 'PAPER Correlator Status Report'
    Mail.defaults {delivery_method :sendmail}
    Mail.deliver do |m|
      m.to to
      m.bcc bcc
      m.subject 'PAPER Correlator Status Report'
      m.body "#{status['timestamp']}\n\n#{status['msg']}"
    end
  else
    puts status['msg']
  end
end

status = 0
status += check_outdumps
status += check_gpugbps

puts "Detected #{status} error#{status != 1 ? 's' : ''}"

# End redirect of $stdout to msgio
$stdout = STDOUT

# Get message string
msg = msgio.string

# Create scrubbed message (remove sampled values)
# Note that .*? is a lazy match (i.e. non-greedy).
scrubbed_msg = msg.gsub(/\(.*?\)/, '(*)')

last_status = REDIS.hgetall(KEY)

# If message changed (or force), update redis and output message
if scrubbed_msg != last_status['msg'] || OPTS[:force]
  last_status['timestamp'] = DateTime.now.new_offset(0)
  last_status['msg'] = msg
  send_message(last_status, OPTS)
  last_status['msg'] = scrubbed_msg
  REDIS.mapped_hmset(KEY, last_status)
  exit 1
end

# If message has not changed, but status is non-zero, exit with 2
if status > 0
  exit 2
end

# Status was and is still 0 (i.e. no errors), exit with 0
exit 0
