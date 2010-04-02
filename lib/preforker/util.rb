# -*- encoding: binary -*-

require 'fcntl'
require 'tmpdir'

class Preforker
  class TmpIO < ::File

    # for easier env["rack.input"] compatibility
    def size
      # flush if sync
      stat.size
    end
  end

  class Util
    def self.is_log?(fp)
      append_flags = File::WRONLY | File::APPEND

      ! fp.closed? &&
        fp.sync &&
        fp.path[0] == ?/ &&
        (fp.fcntl(Fcntl::F_GETFL) & append_flags) == append_flags
    end

    # creates and returns a new File object.  The File is unlinked
    # immediately, switched to binary mode, and userspace output
    # buffering is disabled
    def self.tmpio
      fp = begin
             TmpIO.open("#{Dir::tmpdir}/#{rand}",
                        File::RDWR|File::CREAT|File::EXCL, 0600)
           rescue Errno::EEXIST
             retry
           end
      File.unlink(fp.path)
      fp.binmode
      fp.sync = true
      fp
    end
  end
end
