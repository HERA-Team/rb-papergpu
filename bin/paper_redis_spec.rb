#!/usr/bin/env ruby

# Creates a PNG file of thumbnails of autocorrelations for 128 antennas using
# data stored in redis.  Also outputs text suitable for piping to "mail -~
# recipient" that will attach the graphic to the message and mail it.
#
# Example:
#
# $ paper_redis_spec.rb | mail -~ -b paperblog paperinfo

require 'rubygems'
require 'redis'
require 'astroutil'
require 'mirffi'
require 'pgplot/plotter'
include Pgplot

NANTS = 128
LONGITUDE = Float(ENV['LONGITUDE'] || +21.42829).d2r

redis = Redis.new(host:'redishost')

bw = 0.1
f0 = 0.1
nchan = 1024
sdf = bw / nchan
freqs = NArray.float(nchan).indgen!.mul!(sdf).add!(f0+sdf/2)

# Pixel size of subplot
width  =  96
height = 128

# Number of subplots in X and Y directions
nx =  16
ny = (NANTS + nx - 1) / nx

# Set size of graphic
ENV['PGPLOT_PNG_WIDTH']  = "#{width*nx}"
ENV['PGPLOT_PNG_HEIGHT'] = "#{height*ny}"

xcolor = Color::RED_MAGENTA
ycolor = Color::BLUE_CYAN

jd = nil
ch = 1 # character heigth
filename = '/dev/null'

NANTS.times do |a|
  xx = redis.hgetall("visdata://#{a}/#{a}/xx") rescue {}
  yy = redis.hgetall("visdata://#{a}/#{a}/yy") rescue {}

  if jd.nil?
    # Get time from xx or yy, default to 0 if not present
    jd = ((xx||yy)['time']||0).to_f

    filename = 'rms.%.5f.png' % jd
    Plotter.new(:device=>"#{filename}/png", :nx=>nx, :ny=>ny, :ask=>false)
    ch = pgqch
  end

  xxdata = xx['data']
  yydata = yy['data']

  # Plot box first
  plot([freqs.min, freqs.max], [0, 0],
      :title => '',
      :xlabel => '',
      :ylabel => '',
      :line => nil,
      :yrange => 0..5
      )

  # Put X/Y legend in first subplot of each row
  if a % nx == 0
    pgsch(8)

    pgsci(xcolor)
    pgmtxt('B', -0.4, 0.13, 0.0, 'X')

    pgsci(ycolor)
    pgmtxt('B', -0.4, 0.25, 0.0, 'Y')

    pgsch(ch)
  end

  # If no data
  if xxdata.nil? && yydata.nil?
    # Plot "No Data" message
    pgsch(6)
    pgmtxt('LV', -1, 0.5, 0, 'No Data')
    pgsch(ch)
    next
  end

  # If YY data exists
  if xxdata
    # Unpack string into NArray
    xxdata = NArray.to_na(xxdata, NArray::SFLOAT)

    # Convert to RMS
    xxdata = xxdata.div!(2) ** 0.5

    # Plot XX data
    plot(freqs, xxdata,
        :line_color => xcolor,
        :overlay => true
        )
  end

  # If YY data exists
  if yydata
    # Unpack string into NArray
    yydata = NArray.to_na(yydata, NArray::SFLOAT)

    # Convert to RMS
    yydata = yydata.div!(2) ** 0.5

    # Plot YY data
    plot(freqs, yydata,
        :line_color => ycolor,
        :overlay => true
        )
  end

  # Put antenna number in upper left corner
  pgsch(8)
  pgsci(Color::WHITE)
  pgmtxt('T', -1, 0.90, 1.0, "#{a}")
  pgsch(ch)

end # nants loop

# Close plot
pgclos

lst = Mirffi.jullst(jd, LONGITUDE).r2h

printf "~sPSA128 Auto Plot for %.5f\n", jd
printf "~@ #{filename}\n"
printf "JD %.5f   LST %s\n", jd, lst.to_hmsstr(0)
printf "%s\n", DateTime.ajd(jd).to_local.strftime('%+')
puts
