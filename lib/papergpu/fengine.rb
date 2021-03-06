require 'katcp'
require 'papergpu/version'
require 'papergpu/typemap'

module Paper
  class FEngine < KATCP::RoachClient

    BITSTREAM = 'roachf_1024ch_ma_2012_Jul_26_1756.bof'

    def progdev(bitstream=BITSTREAM)
      super(bitstream)
    end

    # Takes an RMS sample and computes RMS for all 8 inputs based on sum and
    # sumsq.  Gateware accumulates sum and sum of squares for 2**16 (65536)
    # samples.
    def rms
      # Take RMS sample
      self.adc_rms_ctrl = 1
      sleep 0.0005
      self.adc_rms_ctrl = 0

      # Read out and compute RMS levels
      levels = adc_rms_levels
      (0..7).map do |i|
        sum, sumsq = *levels[2*i, 2]
        # Fix 24-bit non-sign-extended sum
        sum &= 0xff_ffff # So we don't break when the gateware is fixed
        sum -= ((sum&0x800000) << 1)
        # RMS is sqrt of (mean of the square - square of the mean)
        Math.sqrt(sumsq/65536.0 - (sum/65536.0)**2)
      end
    end

    # Returns the XAUI status bits from the given GbE core.  Reserved and/or
    # undocumented bits are masked to 0.
    #
    # Least significant 8 bits are: 0BSSSS00
    #
    # B=1 means all 4 lanes are bonded
    # S=1 means a lane is sync'd (4 lanes total)
    #
    # Good value is 124; any other value is problematic.
    def gbe_xaui_status(gbe_core)
      read(gbe_core, 9) & 0b01111100
    end

    def switch_xaui_status
      gbe_xaui_status(:switch_gbe3)
    end

    def switch_xaui_ok?
      switch_xaui_status == 0b01111100 # 124
    end

    def gpu_xaui_status
      gbe_xaui_status(:gpu_gbe2)
    end

    def gpu_xaui_ok?
      gpu_xaui_status == 0b01111100 # 124
    end

  end # class FEngine
end # module Paper
