preforker
=========
A gem to easily create protocol agnostic prefork servers.

Example
----------

Let's see an example using the Mac 'say' command.

```ruby
  require 'rubygems'
  require 'preforker'

  #At this point we can open some socket or reserve any other resource you want to share with your workers.
  #Whatever we do before Preforker.new is ran only in the master process.
  say `hi, I\\'m the master`

  Preforker.new(:timeout => 10) do |master|
    #this block is only run by each worker (10 by default)

    #first you should write the code that is needed to be ran
    #once when a new fork is created, initializations, etc.
    `say hi, I\\'m a worker`

    #now you could IO.select a socket, run an EventMachine service (see example), or as we do here,
    #just run a worker loop. Notice that you need to ask master if it wants you alive periodically or
    #else it will kill you after the timeout elapses. Respect your master!
    while master.wants_me_alive? do
      sleep 1
      `say ping pong`
    end

    #here we can do whatever we want to exit gracefully
    `say bye`


  #here we are using #start to daemonize. We could have used #run to just block and then send the INT signal with ctrl-c to stop
  end.start

  puts "I'm the launcher that forked off master, bye bye"
  puts "To kill the server just do: kill -s QUIT `cat preforker.pid`"
```

Remember that to kill the server you need to:

```bash
  kill -s QUIT `cat preforker.pid`
```

See the examples directory and the specs for more examples.

Why? I can always use threads!
------------------------------

As always, it's a matter of trade offs, so it depends on how you ponder the advantages and disadvantages of a preforking architecture for your particular case.
Still notice that you could have a mix of threads and processes, they are independent concepts.

###Advantages


* Reliability. You may be using a third party library or a C extension with memory leaks or segfaults that could break your entire ruby process. If you use a preforking architecture you can just kill the misbehaving process without affecting the rest of your healthy workers.
* Simplicity. When creating servers you can reduce the amount of extra code (thread pools, triggering, callbacks, etc) needed to deal with concurrency. Still you should always be aware that your app will be concurrent and correctly deal with shared resources, locking and possible race conditions. The concurrency aspect is very decoupled from your app (although in a coarse grained way) so in some cases you can add concurrency to a legacy library without changing its code, just by adding processes.

###Disadvantages
* Control. Threads are more fine grained so you have more control over which parts of your app should be concurrent.
* Efficiency. A threaded system is more efficient because context switching is cheap in threaded systems. But note that AFAIK this is still not the case in Ruby, specially if not using REE, see {here}[http://timetobleed.com/ruby-hoedown-slides/].

Configuration options
---------------------

* :timeout. The timeout in seconds, 5 by default. If a worker takes more than this it will be killed and respawned.
* :workers. Number of workers, 10 by default.
* :stdout_path. Path to redirect stdout to. By default it's the log file. You may prefer to use /dev/null or /dev/stdout
* :stderr_path. Path to redirect stderr to. By default it's the log file. You may prefer to use /dev/null or /dev/stderr
* :app_name. The app name, 'preforker' by default. Used for some ps message, log messages messages and pid file name.
* :pid_path. The path to the pid file for this server. By default it's './preforker.pid'.
* :logger. This is Logger.new('./preforker.log') by default

Signals
-------

You can send some signals to master to control the way it handles the workers lifetime.

* WINCH. Gracefully kill all workers but keep master alive
* TTIN. Increase number of workers
* TTOU. Decrease number of workers
* QUIT. Kill workers and master in a graceful way
* TERM, INT. Kill workers and master immediately

Installation
------------

```bash
  gem install preforker
```

Acknowledgments
---------------

Most of the preforking operating system tricks come from [Unicorn](http://unicorn.bogomips.org/). I checked out its source code and read [this](http://tomayko.com/writings/unicorn-is-unix) great introduction by @rtomayko.

To do list
----------

* More tests
* Log rotation through the USR1 signal
* Have something like min_spare_workers, max_workers, max_request_per_worker

Note on Patches/Pull Requests
-----------------------------

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

Copyright
---------

Copyright (c) 2012 Daniel Cadenas. See LICENSE for details.
