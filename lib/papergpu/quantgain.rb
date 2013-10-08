# Code for exploring effects of quantizing Gaussian noise to 4 bits.

require 'gsl'

# Compute RMS of 4-bit quantized Gaussian noise.  +rms+ is the RMS of the
# pre-quantizated Gaussian noise.  Assumes quantization is symmetric (i.e. no
# -8 values).
def qrms(rms=1)
  # Handle trivial boundary condition
  return 0 if rms <= 0
  # Edges of bins [0.0, 0.5, 1.5, ..., 7.5] for positive half
  # Note that first bin is half width
  xe = GSL::Vector.indgen(9,-0.5); xe[0] = 0
  # Compute quantized CDF
  cdf = GSL::Cdf::gaussian_P(xe,rms)
  # Saturate everthing into last bin
  cdf[-1] = 1
  # Compute quantized PDF (note that zero bin is 1/2 its true probability)
  pdf = cdf.diff

  # Compute RMS of quantized PDF
  xx = GSL::Vector.indgen(8)
  qrms = (2 * xx**2 * pdf).sum ** 0.5
end

# Compute the gain that would result from quantizing a Gaussian noise signal
# with RMS +rms+ to four bits.
def qgain(rms=1)
  qrms(rms)/rms
end

# Inverse of qrms.  Given the RMS of Gaussian noise quantized to 4 bits,
# determine the RMS of the signal prior to quantization.
def qinvrms(rms=1)
  f = GSL::Function.alloc do |inrms|
    rms - qrms(inrms)
  end
  est_in_rms, iters, status = f.solve([1e-6, 196])
  [est_in_rms, iters, status]
end

# Quantize to four bits with symmetric saturation
def q4b(v)
  q = v.round
  q[q>+7] = +7
  q[q<-7] = -7
  q
end

## I have no idea what this does or why one would want to do it.  Maybe if I
## had commented it when I wrote it...
# def estrms(v, a, b=a)
#   a, b = b, a if a > b
#   na = v.lt(a).count_true
#   nb = v.le(b).count_true
#   np = nb - na
#   p np
#   n = v.length.to_f
#   f = GSL::Function.alloc do |sr2|
#     GSL::Sf::erf((b+0.5)/sr2)/2 - 
#     GSL::Sf::erf((a-0.5)/sr2)/2 - 
#     np/n
#   end
#   est, iters, status = f.solve([1e-6, 196])
#   [est/Math.sqrt(2), iters, status]
# end

# Add Integer#bit_count method
class Integer
  # Retuns number of bits set in +self+, which must be non-negative.
  def bit_count
    raise 'cannot count bits of negative number' if self < 0
    count = 0
    n = self
    while n > 0 
      count += 1
      # Clear least significant '1' bit
      n &= (n-1)
    end
    count
  end
end

# Compute signal levels for Gaussian noise passing through the PAPER F engine.
#
# +adc_rms+ is the RMS of the input in ADC counts.
# +fft_stages+ is the number of stages in the FFT.
# +fft_shift+ is the number of stages in the FFT that downshift their output.
# +eq+ is the equalization factor.
# +pf_shift+ is the number of downshifts in the PFB.  The version of the CASPER
# PFB block used by PAPER downshifts the PFB output by one bit, so this
# parameter defaults to 1.
#
# Returns an array of RMS values plus autocorrelation power:
#
#   [pfb_rms, fft_rms, reim_rms, eq_rms, quant_rms, auto_pwr]
#
# +pfb_rms+ is the RMS of the (real) PFB output in ADC counts.
#
# +fft_rms+ is the RMS of the (complex) FFT output in ADC counts.
#
# +reim_rms+ is the RMS of real or imaginary component of the FFT output in ADC
# counts.
#
# + eq_rms is the RMS of the equalizer output just before quantization in
# quantization units (aka "quants").
#
# +quant_rms+ is the RMS of the 4-bit quantizer output in quantization units
# (quants).
#
# +auto_pwr+ is the autocorrelation power (normalized by the number of samples
# integration) in quants**2 (i.e. quants squared).
def paper_levels(adc_rms, fft_stages, fft_shift, eq, pf_shift=1)
  # Polyphase filter gain for noise is 0.894165524491819 * 2**(-pf_shift)
  # The 0.894165524491819 factor is for a 2**11 channel 4-tap CASPER PFB using
  # a "hamming" window.  The matlab code to compute that gain is:
  #
  #   h=reshape(pfb_coeff_gen_calc(11,4,'hamming',1,1,1,-1,0),2^11,4);
  #   mean(sqrt(sum(h.^2, 2)))
  pf_rms = adc_rms * 0.894165524491819 * 2**-pf_shift

  # FFT gain for noise is 2**0.5 for each stage and 2**-1 for each shift
  # Make sure fft_shift doesn't have any extra bits
  fft_shift &= (1<<fft_stages)-1
  fft_rms = pf_rms * 2**(0.5*fft_stages-fft_shift.bit_count)

  # Real/imag component RMS is 1/sqrt(2) of eq_rms
  reim_rms = fft_rms * 2**-0.5

  # Eq gain is eq gain
  eq_rms = reim_rms * eq

  # Eq rms scaled to pre-quantizer integer units is:
  # eq_rms * 8 / 128 == eq_rms / 16
  # The divide by 128 converts ADC units into normalized value in the interval
  # [-1, +1), and the multiply by 8 converts to integer quantization units
  # instead of the normalized 2**-3 quantization units used internally.
  eq_rms_int = eq_rms / 16

  # Quantization gain is computed and applied by qrms function.
  quant_rms = qrms(eq_rms_int)
  # Return them all
  [pf_rms, fft_rms, reim_rms, eq_rms_int, quant_rms]
end
