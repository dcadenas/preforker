require 'rubygems'
require 'bunny'

Bunny.run(:host => 'dcadenas-laptop.local', :port => 5672, :user => 'guest', :password => 'guest') do |b|
  e = b.exchange('test_exchange', :type => :fanout)

  25.times do |i|
    e.publish("number #{i}")
  end
end

