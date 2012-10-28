#!/usr/bin/env ruby

# Prints "bad frame" counter from given F Engines (or pf1 to pf16 if none
# given).

require 'rubygems'
require 'papergpu'

pfnames = ARGV[0] ? ARGV : (1..16).map {|pfn| "pf#{pfn}"}

pfnames.each do |pfn|
  pf = Paper::FEngine.new(pfn)
  bframe = pf.switch_gbe_bframe rescue 'N/A'
  printf "%-4s %10d\n", pf.host,  pf.switch_gbe_bframe
end
