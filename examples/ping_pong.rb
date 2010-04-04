require 'rubygems'
require 'preforker'

#you can open some socket here or reserve any other resource you want to share with your workers, this is master space
Preforker.new(:timeout => 10) do |master|
  #this block is only run from each worker (10 by default)

  #here you should write the code that is needed to be ran each time a fork is created, initializations, etc.
  `say hi`

  #here you could IO.select a socket, run an EventMachine service (see example), or just run worker loop
  #you need to ask master if it wants you alive periodically or else it will kill you after the timeout elapses. Respect your master!
  while master.wants_me_alive? do
    sleep 1
    `say ping pong`
  end

  #here we can do whatever we want when exiting gracefully
  `say bye`
end.start

#to kill the server just run: kill -s QUIT `cat preforker.pid`
