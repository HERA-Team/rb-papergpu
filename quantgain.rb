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
def paper_levels(adc_rms, fft_stages, fft_shift, eq, pf_shift=1)
  # Polyphase filter gain for noise is 0.897484925825201 * 2**(-pf_shift)
  pf_rms = adc_rms * 0.897484925825201 * 2**-pf_shift
  # FFT gain for noise is 2**0.5 for each stage and 2**-1 for each shift
  # Make sure fft_shift doesn't have any extra bits
  fft_shift &= (1<<fft_stages)-1
  fft_rms = pf_rms * 2**(0.5*fft_stages-fft_shift.bit_count)
  # Real/imag component RMS is 1/sqrt(2) of eq_rms
  reim_rms = fft_rms * 2**-0.5
  # Eq gain is eq gain
  eq_rms = reim_rms * eq
  # Quantization gain is computed and applied by qrms function, but we need to
  # scale by 2**-4 (actually, 2**(4-adc_bits)) beforehand since quantization
  # happens on top four bits.
  quant_rms = qrms(eq_rms * 2**-4)
  # Return them all
  [pf_rms, fft_rms, reim_rms, eq_rms, quant_rms]
end
