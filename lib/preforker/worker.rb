#all this code is called inside a forked block
require 'preforker/util'

class Preforker
  class Worker
    class WorkerAPI
      attr_reader :logger

      def initialize(worker, master)
        @master = master
        @logger = master.logger
        @worker = worker
        @alive = @worker.tmp
        @last_file_bit = 0
      end

      def wants_me_alive?
        if @alive
          #we are alive, let's be thankful and tell master we are alive and happy
          @last_file_bit = 0 == @last_file_bit ? 1 : 0
          @alive.chmod(@last_file_bit)
        end
        @alive
      end

      def kill
        if @alive
          @worker.log "Exiting gracefully"
          @alive = false
        end
      end
    end

    attr_reader :tmp
    attr_accessor :pid

    def initialize(worker_block, master)
      @worker_block = worker_block
      @master = master
      @tmp = Util.tmpio
    end

    def init_self_pipe!
      @read_pipe, @write_pipe = IO.pipe
      [@read_pipe, @write_pipe].each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
    end

    def work
      log "Created"
      init

      @worker_block.call(@master_api) if @master_api.wants_me_alive?
    end

    def init
      init_self_pipe!
      handle_signals
      tmp.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
      @master_api = WorkerAPI.new(self, @master)
    end

    def handle_signals
      [:TERM, :INT].each do |sig|
        trap(sig) { exit!(0) }
      end

      [:EXIT, :QUIT].each do |sig|
         trap(sig){ @master_api.kill }
      end

      #what usr1 does
      trap(:USR1) { @read_pipe.close rescue nil }
      trap(:CHLD, 'DEFAULT')
    end

    def proc_message(message)
      full_message = ["#{@master.app_name} Child #{$$}", message].join(": ")
      $0 = full_message
    end

    def log(message)
      full_message = proc_message(message)
      @master.logger.info full_message
    end
  end
end
