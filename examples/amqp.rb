require 'rubygems'
require 'preforker'
require 'mq'

#be sure to run your AMQP server first

Preforker.new(:timeout => 5, :workers => 4, :app_name => "Amqp example") do |master|
  AMQP.start(:host => 'dcadenas-laptop.local') do
    EM.add_periodic_timer(1) do
      AMQP.stop{ EM.stop } unless master.wants_me_alive?
    end

    MQ.prefetch(1)
    channel = MQ.new
    test_exchange = channel.fanout('test_exchange')
    channel.queue('test_queue').bind(test_exchange).subscribe(:ack => true) do |h, msg|
      $stdout.puts "#{$$} received #{msg.inspect}"
      h.ack
    end
  end
end.start

#run examples/amqp_client.rb to see the output
#kill server with: kill -s TERM `cat 'amqp example.pid'`
