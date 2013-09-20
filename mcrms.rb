#!/usr/bin/env ruby

# Read "adc_sum_squares" and "adc_sum" from memcached and compute RMS
# using this formula...
#
# rms = sqrt(adc_sum_squares/N - (adc_sum/N)**2)
#
# ...where N is 65536

require 'rubygems'
require 'memcached'
require 'narray'
include NMath

N = 65536

mc = Memcached.new('paper1', :binary_protocol => true)

roach = 'px1'
sum_sq_str = mc.get("#{roach}:adc_sum_squares", nil)
sum_str    = mc.get("#{roach}:adc_sum", nil)

=begin
sum_sq = NArray.to_na(sum_sq_str, NArray::INT).ntoh.to_type(NArray::FLOAT)
sumu   = NArray.to_na(sum_str,    NArray::INT).ntoh
# Convert sum to twos complement
sum = ((sumu ^ (1<<23)) - (1<<23)).to_type(NArray::FLOAT)

mean_of_squares = sum_sq / N
square_of_mean  = (sum / N) ** 2

rms = sqrt(mean_of_squares - square_of_mean)

rms.length.times do |i|
  printf "%d %d %f %f %f\n",
    sum_sq[i], sum[i], mean_of_squares[i], square_of_mean[i], rms[i]
end
=end

sum_sq = NArray.to_na(sum_sq_str, NArray::INT).ntoh.to_type(NArray::FLOAT)
sumu   = NArray.to_na(sum_str,    NArray::INT).ntoh
sumu.each {|s| puts '%08x' % s}
puts
# Convert sum to twos complement
sum = ((sumu ^ (1<<23)) - (1<<23)).to_type(NArray::FLOAT)

#rms = sqrt(N*sum_sq - sum**2)/N
rms = []
sum.length.times do |i|
  rms[i] = sqrt(N*sum_sq[i] - sum[i]**2)/N
end

rms.length.times do |i|
  printf "%d %d %f\n",
    sum_sq[i], sum[i], rms[i]
end
