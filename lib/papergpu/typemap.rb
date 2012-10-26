require 'katcp'
require 'papergpu/version'

module Paper
  class FEngine < KATCP::RoachClient

    # Override RoachClient::device_typemap
    def device_typemap; DEVICE_TYPEMAP end

    DEVICE_TYPEMAP = {
      :adc_rms_ctrl                => :rwreg,
      :adc_rms_levels              => :bram,
      :adc_snap_0_3                => :bram,
      :adc_snap_4_7                => :bram,
      :adc_snap_ctrl               => :rwreg,

      :ant_base                    => :rwreg,
      :delay_values                => :rwreg,

      :eq_0_coeffs                 => :bram,
      :eq_1_coeffs                 => :bram,
      :eq_2_coeffs                 => :bram,
      :eq_3_coeffs                 => :bram,

      :feng_ctl                    => :rwreg,

      :fft_shift                   => :rwreg,

      :gbe_sw_port                 => :rwreg,
      :gpu_gbe2                    => :bram,
      :gpu_gbe_status              => :roreg,
      :gpu_ip                      => :rwreg,
      :gpu_mcnt_lsb                => :roreg,
      :gpu_mcnt_msb                => :roreg,
      :gpu_port                    => :rwreg,
      :gpu_txsnap_addr             => :roreg,
      :gpu_txsnap_bram_lsb         => :bram,
      :gpu_txsnap_bram_msb         => :bram,
      :gpu_txsnap_bram_oob         => :bram,
      :gpu_txsnap_ctrl             => :rwreg,

      :input_selector              => [:rwreg, :insel],

      :ip_base                     => :rwreg,

      :loopback_cnts_data_lsb      => :bram, # ???
      :loopback_cnts_data_msb      => :bram, # ???
      :loopback_loop_cnt           => :roreg,
      :loopback_loop_err_cnt       => :roreg,
      :loopback_loop_over          => :roreg,
      :loopback_loop_under         => :roreg,
      :loopback_rx_cnt             => :roreg,
      :loopback_rx_err_cnt         => :roreg,
      :loopback_rx_over            => :roreg,
      :loopback_rx_pkt_too_big     => :roreg,
      :loopback_rx_pkt_too_small   => :roreg,
      :loopback_rx_under           => :roreg,

      :my_ip                       => :rwreg,
      :n_inputs                    => :rwreg,
      :qdr0_ctrl                   => :skip, # ???
      :qdr0_memory                 => :skip, # ???
      :seed_data                   => :rwreg,

      :switch_cnts_data_lsb        => :bram, # ???
      :switch_cnts_data_msb        => :bram, # ???
      :switch_gbe3                 => :bram,
      :switch_gbe_bframe           => :roreg,
      :switch_gbe_oflow            => :roreg,
      :switch_gbe_orun             => :roreg,
      :switch_gbe_status           => :roreg,
      :switch_rxsnap_addr          => :roreg,
      :switch_rxsnap_bram_lsb      => :bram,
      :switch_rxsnap_bram_msb      => :bram,
      :switch_rxsnap_bram_oob      => :bram,
      :switch_rxsnap_ctrl          => :rwreg,
      :switch_txsnap_addr          => :roreg,
      :switch_txsnap_bram_lsb      => :bram,
      :switch_txsnap_bram_msb      => :bram,
      :switch_txsnap_bram_oob      => :bram,
      :switch_txsnap_ctrl          => :rwreg,

      :sys_board_id                => :skip,
      :sys_clkcounter              => :skip,
      :sys_rev                     => :skip,
      :sys_rev_rcs                 => :skip,
      :sys_scratchpad              => :skip,
    }
  end # class FEngine
end # module Paper
