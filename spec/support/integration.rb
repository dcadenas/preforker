module Integration
  PREFORKER_LIB_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib'))
  def run_preforker(code)
    File.open("test.rb", 'w') do |f|
      f.write <<-TOP
        $LOAD_PATH.unshift('#{PREFORKER_LIB_PATH}')
        require 'preforker'
      TOP
      f.write(code)
    end

    system("ruby test.rb")
  end

  def sandboxed_it(desc)
    it desc do
      with_files do
        yield
        term_server
      end
    end
  end

  def signal_server(signal)
    Dir['*.pid'].each do |pid_file_path|
      Process.kill(signal, File.read(pid_file_path).to_i)
    end
  end

  def term_server
    signal_server(:TERM)
    wait_till_server_ends
  end

  def quit_server
    signal_server(:QUIT)
    wait_till_server_ends
  end

  def int_server
    signal_server(:INT)
    wait_till_server_ends
  end

  def wait_till_server_ends
    Dir['*.pid'].each do |pid_file_path|
      while File.exists?(pid_file_path) do
        sleep 0.2
      end
    end
  end
end
