require 'rubygems'
require 'preforker'
require 'eventmachine'

class EchoServer < EM::Connection
  def notify_readable
    while socket = @io.accept_nonblock
      message = socket.gets
      socket.write message
      #let's fake some more work is done
      sleep 0.3
      socket.close
    end
  rescue Errno::EAGAIN, Errno::ECONNABORTED
  end

  def unbind
    detach
    @io.close
  end
end

socket = TCPServer.new("0.0.0.0", 8081)
socket.listen(100)
EventMachine.epoll

Preforker.new(:timeout => 5, :workers => 4, :app_name => "EM example") do |master|
  EventMachine::run do
    EM.add_periodic_timer(4) do
      EM.stop_event_loop unless master.wants_me_alive?
    end

    EM.watch(socket, EchoServer, self){ |c| c.notify_readable = true}
    puts "Listening..."
  end
end.start

__END__
ab -c 4 -n 100 "http://127.0.0.1:8081/"

Concurrency Level:      4
Time taken for tests:   8.202 seconds
Complete requests:      100


##################################
Compare it with this other implementation that doesn't use preforker (or EM.defer)

EventMachine::run do
  EM.watch(socket, EchoServer, self){ |c| c.notify_readable = true}
  puts "Listening..."
end

ab -c 4 -n 100 "http://127.0.0.1:8081/"

Concurrency Level:      4
Time taken for tests:   29.729 seconds
Complete requests:      100

