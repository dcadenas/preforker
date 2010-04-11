require 'rubygems'
require 'preforker'

#you can open some socket here or reserve any other resource you want to share with your workers, this is master space
`say hi, I\\'m the master`

Preforker.new(:timeout => 10) do |master|
  #this block is only run from each worker (10 by default)

  #here you should write the code that is needed to be ran once each time a fork is created, initializations, etc.
  `say hi, I\\'m a worker`

  #here you could IO.select a socket, run an EventMachine service (see example), or just run worker loop
  #you need to ask master if it wants you alive periodically or else it will kill you after the timeout elapses. Respect your master!
  while master.wants_me_alive? do
    sleep 1
    `say ping pong`
  end

  #here we can do whatever we want when exiting gracefully
  `say bye`

#we can use run instead of start to run the server without daemonizing
end.start

puts "I'm the launching process that forked to create master, I did my job. Enjoy the noisy ping pong championship, bye bye!"
puts "To kill the server just do: kill -s QUIT `cat preforker.pid`
