import numpy as N
import numpy.random as R
import optparse,sys

# This script tests the signal levels going into the roach.
# Data path 
#
#
#
#
#
o = optparse.OptionParser()
o.add_option('-q','--quant',dest='quantize', default=4, type='int',help='How many bits to quantize to. ')
#o.add_option('-r', '--rms', dest='rms', type=float, help='RMS value of signal going into equalizer')
o.add_option('-i', '--rmsin', dest='rms_in', default = 16, type=float, help='RMS value of signal')
o.add_option('-f', '--fft', dest='fft_shift', default = 12, type = int, help='Number of shifts in the fft')
o.add_option('-e', '--eq', dest='eq', default = 1500, type = int, help='equalizer coefficient')

opts,args = o.parse_args(sys.argv[1:])


actual_rms = opts.rms_in*2**-7*(0.9)*(2**-1)*(2**(6-opts.fft_shift))*(2**-.5)*opts.eq

print ''
print 'RMS into quantizers = %f , %f/8'%(actual_rms, actual_rms*8)
print ''
signal = R.randn(2e5)
print 'standard deviation of random normal signal=',N.std(signal)
print ''
rms_sig = signal * actual_rms 
print 'standard deviation of random normal signal multiplied by rms=',N.std(rms_sig)
print ''
q_sig = N.round(rms_sig*8)
q = opts.quantize
q_sig[N.where(q_sig > (q*2 -1))] = q*2 -1
q_sig[N.where(q_sig < -(q*2 -1))] = -(q*2-1)

print 'rms after quantizing = %f ( %f/8).' %((N.std(q_sig)/8.), N.std(q_sig))
print 'rms after combining real and imaginary = %f (%f/8)'%(((N.std(q_sig)/8.)*2**.5), (N.std(q_sig)*2**.5))
