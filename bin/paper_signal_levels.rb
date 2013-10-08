#!/usr/bin/env ruby

# This script predicts the signal levels throughout the PAPER correlator
# for a given input RMS, PFB shift amount, fft shift amount, and EQ
# coefficient.

require 'optparse'
require 'ostruct'
require 'paper/quantgain'

OPTS = OpenStruct.new
OPTS.in_rms = 16
OPTS.nshift = 12
OPTS.pfb_shift = 1
OPTS.eq = Rational(1500)

OptionParser.new do |op|
  op.program_name = File.basename($0)

  op.banner = "Usage: #{op.program_name} [OPTIONS]"
  op.separator('')
  op.separator('Compute predicted signal levels throughout the PAPER correlator')
  op.separator('for a given input RMS, PFB shift, FFT shift, and EQ coefficient.')
  op.separator('')
  #op.on('-q', '--quant', dest='quantize', default=4, type='int',help='How many bits to quantize to. ')
  op.on('-i', '--in-rms=RMS', Float, "RMS value of input signal [#{OPTS.in_rms}]") do |o|
    OPTS.in_rms = o
  end
  op.on('-f', '--fft=NSHIFT', Integer, "Number of shifts in the fft [#{OPTS.nshift}]") do |o|
    OPTS.nshift = o
  end
  op.on('-p', '--pfb=NSHIFT', Integer, "Number of shifts in the pfb [#{OPTS.pfb_shift}]") do |o|
    OPTS.pfb_shift = o
  end
  op.on('-e', '--eq=COEF', "Equalizer coefficient [#{OPTS.eq}]") do |o|
    OPTS.eq = Rational((128*Rational(o)).round, 128)
  end
  op.on_tail('-h','--help','Show this message') do
    puts op.help
    exit
  end
end.parse!

NSTAGES = 11

pf_rms, fft_rms, reim_rms, eq_rms, quant_rms = paper_levels(OPTS.in_rms, NSTAGES, (1<<OPTS.nshift)-1, OPTS.eq, OPTS.pfb_shift)

printf "ADC   output RMS %8.4f counts\n", OPTS.in_rms
printf "PFB   output RMS %8.4f counts\n", pf_rms
printf "FFT   output RMS %8.4f counts\n", fft_rms
printf "ReIm  output RMS %8.4f counts", reim_rms
if reim_rms > 128
  printf " <-- WARNING: RMS exceeds dynamic range"
elsif reim_rms > 32
  printf " <-- WARNING: headroom is only %.1f sigma", 128/reim_rms
end
puts
printf "EQ    output RMS %8.4f quants\n", eq_rms
printf "QUANT output RMS %8.4f quants\n", quant_rms
printf "AUTOCORRELATION  %8.4f quants**2\n", quant_rms**2 * 2
