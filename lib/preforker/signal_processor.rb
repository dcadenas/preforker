class Preforker
  class SignalProcessor
    attr_reader :interesting_signals, :signal_queue
    def initialize(master)
      @read_pipe, @write_pipe = IO.pipe
      @master = master
      @signal_queue = []
      @interesting_signals = [:WINCH, :QUIT, :INT, :TERM, :USR1, :USR2, :HUP, :TTIN, :TTOU]
      @interesting_signals.each { |sig| trap_deferred(sig) }
    end

    def trap_deferred(signal)
      trap(signal) do
        if @signal_queue.size < 5
          @signal_queue << signal
          wake_up_master
        else
          @master.logger.error "ignoring SIG#{signal}, queue=#{@signal_queue.inspect}"
        end
      end
    end

    def start_signal_loop
      last_check = Time.now
      begin
        loop do
          @master.reap_all_workers
          case @signal_queue.shift
            when nil
              # avoid murdering workers after our master process (or the
              # machine) comes out of suspend/hibernation
              @master.murder_lazy_workers if (last_check + @master.timeout) >= (last_check = Time.now)
              @master.maintain_worker_count
              sleep_master
            when :WINCH
              @master.logger.info "Gracefully stopping all workers"
              @master.number_of_workers = 0
            when :TTIN
              @master.number_of_workers += 1
            when :TTOU
              @master.number_of_workers -= 1 if @master.number_of_workers > 0
            when :QUIT # graceful shutdown
              break
            when :TERM, :INT # immediate shutdown
              @master.stop(false)
              break
          end
        end
      rescue Errno::EINTR
        retry
      rescue => e
        @master.logger.error "Unhandled master loop exception #{e.inspect}.\n#{e.backtrace.join("\n")}"
        retry
      ensure
        @master.logger.info "Master quitting"
        @master.quit
      end
    end

    # wait for a signal hander to wake us up and then consume the pipe
    # Wake up every second anyways to run murder_lazy_workers
    def sleep_master
      begin
        maximum_sleep = @master.timeout > 1 ? 1 : @master.timeout / 2
        ready = IO.select([@read_pipe], nil, nil, maximum_sleep) or return
        ready.first && ready.first.first or return
        chunk_size = 16 * 1024
        loop { @read_pipe.read_nonblock(chunk_size) }
      rescue Errno::EAGAIN, Errno::EINTR
      end
    end

    def wake_up_master
      begin
        @write_pipe.write_nonblock('.') # wakeup master process from select
      rescue Errno::EAGAIN, Errno::EINTR
        # pipe is full, master should wake up anyways
        retry
      end
    end

    def reset
      @interesting_signals.each { |sig| trap(sig, nil) }
      @signal_queue.clear
    end
  end
end
