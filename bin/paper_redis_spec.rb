#!/usr/bin/env ruby

require 'rubygems'
require 'redis'
require 'astroutil'
require 'pgplot/plotter'
include Pgplot

redis = Redis.new(host:'redishost')

key = "visdata://0/0/xx"

while true
  time = redis.hget(key, :time)
  data = NArray.to_na(redis.hget(key, :data), NArray::SFLOAT)
  plot(data,
      :title => "#{key} @ #{DateTime.jd(time.to_f)}",
      :xlabel => 'Channel',
      :ylabel => 'Ampitude'
      )
  sleep 1 while time == redis.hget(key, :time)
end


