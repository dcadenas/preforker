class Preforker
  class  PidManager
    attr_reader :pid_path, :pid

    def initialize(pid_path)
      set_pid_path(pid_path, $$)
    end

    def set_pid_path(new_pid_path, new_pid)
      if new_pid_path
        if read_pid = read_path_pid(new_pid_path)
          return new_pid_path if @pid_path && new_pid_path == @pid_path && read_pid == @pid
          raise ArgumentError, "#{$$} Already running on PID:#{read_pid} (or #{new_pid_path} is stale)"
        end
      end
      unlink_pid_safe(@pid_path) if @pid_path

      if new_pid_path
        fp = begin
               tmp = "#{File.dirname(new_pid_path)}/#{rand}.#{pid}"
               File.open(tmp, File::RDWR|File::CREAT|File::EXCL, 0644)
             rescue Errno::EEXIST
               retry
             end
        fp.syswrite("#{new_pid}\n")
        File.rename(fp.path, new_pid_path)
        fp.close
      end

      @pid = new_pid
      @pid_path = new_pid_path
    end

    # unlinks a PID file at given +path+ if it contains the current PID
    # still potentially racy without locking the directory (which is
    # non-portable and may interact badly with other programs), but the
    # window for hitting the race condition is small
    def unlink
      File.unlink(@pid_path) if @pid_path && File.read(@pid_path).to_i == @pid
    rescue
    end

    private

    # returns a PID if a given path contains a non-stale PID file,
    # nil otherwise.
    def read_path_pid(path)
      pid = File.read(path).to_i
      return nil if pid <= 0
      begin
        Process.kill(0, pid)
        pid
      rescue Errno::ESRCH
        # don't unlink stale pid files, racy without non-portable locking...
      end
    rescue Errno::ENOENT
    end
  end
end
