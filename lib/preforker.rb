require 'socket'
require 'fcntl'
require 'preforker/pid_manager'
require 'preforker/worker'
require 'preforker/signal_processor'
require 'logger'

class Preforker
  attr_reader :timeout, :app_name, :logger
  attr_accessor :number_of_workers

  def initialize(options = {}, &worker_block)
    @app_name = options[:app_name] || "Preforker"
    default_log_file = "#{@app_name.downcase}.log"
    @options = {
      :timeout => 5,
      :workers => 10,
      :app_name => "Preforker",
      :stderr_path => default_log_file,
      :stderr_path => default_log_file
    }.merge(options)

    @logger = @options[:logger] || Logger.new(default_log_file)

    @timeout = @options[:timeout]
    @number_of_workers = @options[:workers]
    @worker_block = worker_block || lambda {}

    @workers = {}
    $0 = "#@app_name Master"
  end

  def start
    launch do |ready_write|
      $stdin.reopen("/dev/null")
      set_stdout_path(@options[:stdout_path])
      set_stderr_path(@options[:stderr_path])

      logger.info "Master started"

      pid_path = @options[:pid_path] || "./#{@app_name.downcase}.pid"
      @pid_manager = PidManager.new(pid_path)
      @signal_processor = SignalProcessor.new(self)

      spawn_missing_workers do
        ready_write.close
      end

      #tell parent we are ready
      ready_write.syswrite($$.to_s)
      ready_write.close rescue nil

      @signal_processor.start_signal_loop
    end
  end

  def launch(&block)
     puts "Starting server"

     ready_read, ready_write = IO.pipe
     [ready_read, ready_write].each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }

     fork do
       ready_read.close

       Process.setsid
       fork do
         block.call(ready_write)
       end
     end

     ready_write.close
     master_pid = (ready_read.readpartial(16) rescue nil).to_i
     ready_read.close
     if master_pid <= 1
       warn "Master failed to start, check stderr log for details"
       exit!(1)
     else
       puts "Server started successfuly"
       exit(0)
     end
  end

  def close_resources_worker_wont_use
    @signal_processor.reset
    @workers.values.each { |other| other.tmp.close rescue nil }
    @workers.clear
  end

  # Terminates all workers, but does not exit master process
  def stop(graceful = true)
    limit = Time.now + @timeout
    until @workers.empty? || Time.now > limit
      signal_each_worker(graceful ? :QUIT : :TERM)
      sleep(0.1)
      reap_all_workers
    end
    signal_each_worker(:KILL)
  end

  def quit(graceful = true)
    stop(graceful)
    @pid_manager.unlink
  end

  def reap_all_workers
    begin
      loop do
        worker_pid, status = Process.waitpid2(-1, Process::WNOHANG)
        break unless worker_pid
        worker = @workers.delete(worker_pid) and worker.tmp.close rescue nil
        logger.info "reaped #{status.inspect}"
      end
    rescue Errno::ECHILD
    end
  end

  def spawn_missing_workers(new_workers_count = @number_of_workers, &init_block)
    new_workers_count.times do
      worker = Worker.new(@worker_block, self)
      worker_pid = fork do
        close_resources_worker_wont_use
        init_block.call if init_block
        worker.work
      end

      worker.pid = worker_pid
      @workers[worker_pid] = worker
    end
  end

  def maintain_worker_count
    number_of_missing_workers = @number_of_workers - @workers.size
    return if number_of_missing_workers == 0
    return spawn_missing_workers(number_of_missing_workers) if number_of_missing_workers > 0
    @workers.values[0..(-number_of_missing_workers - 1)].each do |unneeded_worker|
      signal_worker(:QUIT, unneeded_worker.pid) rescue nil
    end
  end

  # forcibly terminate all workers that haven't checked in in timeout
  # seconds.  The timeout is implemented using an unlinked File
  # shared between the parent process and each worker.  The worker
  # runs File#chmod to modify the ctime of the File.  If the ctime
  # is stale for >timeout seconds, then we'll kill the corresponding
  # worker.
  def murder_lazy_workers
    @workers.dup.each_pair do |worker_pid, worker|
      stat = worker.tmp.stat
      # skip workers that disable fchmod or have never fchmod-ed
      next if stat.mode == 0100600
      next if (diff = (Time.now - stat.ctime)) <= @timeout
      logger.error "Worker=#{worker_pid} timeout (#{diff}s > #{@timeout}s), killing"
      signal_worker(:KILL, worker_pid) # take no prisoners for timeout violations
    end
  end

  # delivers a signal to a worker and fails gracefully if the worker
  # is no longer running.
  def signal_worker(signal, worker_pid)
    begin
      Process.kill(signal, worker_pid)
    rescue Errno::ESRCH
      worker = @workers.delete(worker_pid) and worker.tmp.close rescue nil
    end
  end

  # delivers a signal to each worker
  def signal_each_worker(signal)
    @workers.keys.each { |worker_pid| signal_worker(signal, worker_pid) }
  end

  def signal_quit
    signal_worker(:QUIT, @pid_manager.pid)
  end

  def set_stdout_path(path)
    redirect_io($stdout, path)
  end

  def set_stderr_path(path)
    redirect_io($stderr, path)
  end

  def redirect_io(io, path)
    File.open(path, 'ab') { |fp| io.reopen(fp) } if path
    io.sync = true
  end
end
