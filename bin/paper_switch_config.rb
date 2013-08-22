#!/usr/bin/env ruby

require 'optparse'
require 'pty'
require 'expect'

# Prompt pattern
PROMPT = /(^console(.*)[>#])|\(q\)uit/

OPTS = {
  :interactive => nil,
  :verbose   => false
}

OP = OptionParser.new do |op|
  op.program_name = File.basename($0)

  op.banner = "Usage: #{op.program_name} [OPTIONS] SWITCH [CMD_FILE] ..."
  op.separator('')
  op.separator('Run commands on Dell 10 GbE switch.  If one or more command')
  op.separator('files are given, use commands from them; otherwise commands')
  op.separator('are taken from STDIN.  If commands are read from STDIN and')
  op.separator('STDIN is a tty, the switch output is displayed.  If commands')
  op.separator('are comming from files or a pipe, the output is displayed only')
  op.separator('if -i is specified.')
  op.separator('')
  op.separator('Options:')
  op.on('-i', '--[no-]interactive', "Force interactive mode [auto]") do |o|
    OPTS[:interactive] = o
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

# Get switch name (and remove from list of files)
switch = ARGV.shift
if switch.nil?
  puts 'no switch name given'
  puts OP.help
  exit
end

# If interactive is auto-mode
if OPTS[:interactive].nil?
  # Are we interactive with user?
  OPTS[:interactive] = (ARGV.empty? && STDIN.tty?)
end

puts "connecting to #{switch}" if OPTS[:verbose]
PTY.spawn("telnet #{switch}") do |r, w, pid|

  # Login
  begin
    r.expect('User:');
  rescue Errno::EIO
    puts "error communicating with switch #{switch}"
    break
  end
  w.puts('admin')
  r.expect('Password:')
  w.puts
  resp, *match = r.expect(PROMPT)
  # Delete all CRs
  resp.gsub!("\r", '')

  # Print clue if interactive
  puts "Enter switch commands.  Type CTRL-D to exit." if OPTS[:interactive]

  # Process command lines
  print resp if OPTS[:interactive]
  ARGF.each_line do |line|
    # If we get a comment-only line, echo it
    if line =~ /^\s*#/
      puts line.sub(/^\s*#\s*/,'')
      next
    end
    # Strip off any trailing comment
    line.gsub!(/\s*#.*/, '')

    # If we have a blank line, ignore it
    if line.strip.empty?
      next
    end

    # Send line to switch
    w.puts line

    begin
      resp, *match = r.expect(PROMPT)
      # Delete the CR SP [...] CR after a "More" line
      resp.sub!(/\r +\r/,'')
      # Then delete all CRs
      resp.gsub!("\r", '')

      # Don't show the pager line
      print resp.gsub(/\n?\n--More-- or \(q\)uit/, '') if OPTS[:interactive]

      # If a pager line, send newline
      if resp =~ /\(q\)uit/
        w.puts
      end
    rescue Errno::EIO
      puts 'connection closed'
      break
    end while resp =~ /\(q\)uit/
  end
end
