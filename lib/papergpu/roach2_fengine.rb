require 'rubygems'
require 'adc16'

# Using a module helps prevent namespace collisions.
module Paper

  # A Ruby/KATCP class for the CASPER-based roach2_fengine design.
  class Roach2Fengine < ADC16

    # The DEVICE_TYPEMAP Hash guides dynamic method creation.
    DEVICE_TYPEMAP = superclass::DEVICE_TYPEMAP.merge({
      :delay_0           => :rwreg,
      :delay_1           => :rwreg,
      :delay_2           => :rwreg,
      :delay_3           => :rwreg,
      :delay_4           => :rwreg,
      :delay_5           => :rwreg,
      :delay_6           => :rwreg,
      :delay_7           => :rwreg,
      :eq_0_coeffs       => :bram,
      :eq_1_coeffs       => :bram,
      :eq_10_coeffs      => :bram,
      :eq_11_coeffs      => :bram,
      :eq_12_coeffs      => :bram,
      :eq_13_coeffs      => :bram,
      :eq_14_coeffs      => :bram,
      :eq_15_coeffs      => :bram,
      :eq_2_coeffs       => :bram,
      :eq_3_coeffs       => :bram,
      :eq_4_coeffs       => :bram,
      :eq_5_coeffs       => :bram,
      :eq_6_coeffs       => :bram,
      :eq_7_coeffs       => :bram,
      :eq_8_coeffs       => :bram,
      :eq_9_coeffs       => :bram,
      :eth_0_gpu         => :tenge,
      :eth_0_gpu_bframes => :roreg,
      :eth_0_gpu_oflows  => :roreg,
      :eth_0_gpu_oruns   => :roreg,
      :eth_0_gpu_status  => :roreg,
      :eth_0_sw          => :tenge,
      :eth_0_sw_bframes  => :roreg,
      :eth_0_sw_oflows   => :roreg,
      :eth_0_sw_oruns    => :roreg,
      :eth_0_sw_status   => :roreg,
      :eth_0_xip         => :rwreg,
      :eth_1_gpu         => :tenge,
      :eth_1_gpu_bframes => :roreg,
      :eth_1_gpu_oflows  => :roreg,
      :eth_1_gpu_oruns   => :roreg,
      :eth_1_gpu_status  => :roreg,
      :eth_1_sw          => :tenge,
      :eth_1_sw_bframes  => :roreg,
      :eth_1_sw_oflows   => :roreg,
      :eth_1_sw_oruns    => :roreg,
      :eth_1_sw_status   => :roreg,
      :eth_1_xip         => :rwreg,
      :eth_2_gpu         => :tenge,
      :eth_2_gpu_bframes => :roreg,
      :eth_2_gpu_oflows  => :roreg,
      :eth_2_gpu_oruns   => :roreg,
      :eth_2_gpu_status  => :roreg,
      :eth_2_sw          => :tenge,
      :eth_2_sw_bframes  => :roreg,
      :eth_2_sw_oflows   => :roreg,
      :eth_2_sw_oruns    => :roreg,
      :eth_2_sw_status   => :roreg,
      :eth_2_xip         => :rwreg,
      :eth_3_gpu         => :tenge,
      :eth_3_gpu_bframes => :roreg,
      :eth_3_gpu_oflows  => :roreg,
      :eth_3_gpu_oruns   => :roreg,
      :eth_3_gpu_status  => :roreg,
      :eth_3_sw          => :tenge,
      :eth_3_sw_bframes  => :roreg,
      :eth_3_sw_oflows   => :roreg,
      :eth_3_sw_oruns    => :roreg,
      :eth_3_sw_status   => :roreg,
      :eth_3_xip         => :rwreg,
      :eth_ctrl          => :rwreg,
      :fft_shift         => :rwreg,
      :fid               => :rwreg,
      :input_rms_enable  => :rwreg,
      :input_rms_levels  => :bram,
      :input_sel0        => :rwreg,
      :input_sel1        => :rwreg,
      :input_sel2        => :rwreg,
      :input_sel3        => :rwreg,
      :monitor_sel       => :rwreg,
      :seed_0            => :rwreg,
      :seed_1            => :rwreg,
      :seed_2            => :rwreg,
      :seed_3            => :rwreg,
      :sync_arm          => :rwreg,
      :sync_count        => :roreg,
      :sync_period       => :roreg,
      :sync_uptime       => [:roreg, :uptime],
      :sys_board_id      => :roreg,
      :sys_clkcounter    => :roreg,
      :sys_rev           => :roreg,
      :sys_rev_rcs       => :roreg,
      :sys_scratchpad    => :rwreg
    }) # :nodoc:

    # The superclass calls this to get our device typemap.
    def device_typemap # :nodoc:
      @device_typemap ||= DEVICE_TYPEMAP.dup
    end

    # Estimates the FPGA clock frequency from consecutive readings of
    # sys_clkcounter.  Returns results in Hz by default; pass 1e6 for +scale+
    # to get MHz etc.  +secs+ is how long to wait between readings of
    # sys_clkcounter.  Waiting more than one wrap around will give invalid
    # results.
    def clk_freq(secs=1, scale=1)
      tic = sys_clkcounter
      sleep secs
      toc = sys_clkcounter
      (toc - tic) % (1<<32) / scale / secs
    end

    # Returns or sets input selectors.  If +opts+ is a Fixnum, Range, or Array,
    # #insel returns the requested input selector register (0-3).  If opts is a
    # Hash, it is expected to have keys of :adc, :n0, :n1, and/or :z.  The
    # corresponding value for each of these keys is a single number or an
    # object responding to #each that represents the input (or inputs) to set
    # to the slector key (:adc = ADC, :n0 = noise0, :n1 = noise1, :z = zero).
    #
    # Examples:
    #
    #   # Set all inputs to ADC
    #   r.insel(:adc => 0..31)
    #
    #   # Set input 1 to noise0 and inputs 2 and 8 to noise1
    #   r.insel(:n0 => 1, :n1 => [2, 8])
    def insel(opts=0..3)
      case opts
      when Fixnum
        send("input_sel#{opts}")
      when Range, Array
        opts.map {|i| send("input_sel#{i}")}
      when Hash
        # Read all current insel values
        insel_vals = insel
        opts.each do |sel, inputs|
          inputs = [inputs] unless inputs.respond_to? :each
          selval = case sel.to_s
                   when 'adc'; 0
                   when 'n0', 'noise0'; 1
                   when 'n1', 'noise1'; 2
                   when 'z', 'zero'; 3
                   else next
                   end
          inputs.each do |i|
            insel_idx   = i / 8;
            insel_shift = (i % 8) * 4;
            insel_mask = (0b11) << insel_shift;
            # Mask off current bits
            insel_vals[insel_idx] &= ~insel_mask;
            # Or in new bits
            insel_vals[insel_idx] |= (selval << insel_shift)
          end # inputs.each
        end # opts.each
        # Write back new insel values
        insel_vals.each_with_index {|v, i| send("input_sel#{i}=", v)}
      end # case opts
    end

    # Used to parameterize delay width.  It used to be 4 bits per input over 4
    # registers, but now it is 8 bits per input over 8 registers.
    BITS_PER_DELAY = 8
    DELAYS_PER_REG = (32/BITS_PER_DELAY)
    DELAY_MASK = (1<<BITS_PER_DELAY) - 1
    # If called with a single Fixnum argument, return the delay for that input number.
    # If called with two arguments, the first is input number and the second is
    # the delay value to set for that input (this case returns self).
    def delay(input, val=nil)
      raise ArgumentError unless (0..31) === input
      input = input.to_i
      reg   =  input / DELAYS_PER_REG
      shift = (input % DELAYS_PER_REG) * BITS_PER_DELAY
      regval = send("delay_#{reg}")
      if val
        regval &= ~( DELAY_MASK        << shift)
        regval |=  ((DELAY_MASK & val) << shift)
        send("delay_#{reg}=", regval)
        self
      else
        (regval >> shift) & DELAY_MASK
      end
    end

  end # class Roach2Fengine
end # module Paper
