require 'spec_helper'

include FileTestHelper
describe "Preforker" do
  sandboxed_it "should quit gracefully" do
    run_preforker <<-CODE
      Preforker.new(:workers => 1) do |master|
        sleep 0.1 while master.wants_me_alive?

        master.logger.info("Main loop ended. Dying")
      end.start
    CODE

    quit_server
    log = File.read("preforker.log")
    log.should =~ /Main loop ended. Dying/
  end

  sandboxed_it "shouldn't quit gracefully on term signal" do
    run_preforker <<-CODE
      Preforker.new(:workers => 1) do |master|
        sleep 0.1 while master.wants_me_alive?

        master.logger.info("Main loop ended. Dying")
      end.start
    CODE

    term_server
    log = File.read("preforker.log")
    log.should_not =~ /Main loop ended. Dying/
  end

  sandboxed_it "shouldn't quit gracefully on int signal" do
    run_preforker <<-CODE
      Preforker.new(:workers => 1) do |master|
        sleep 0.1 while master.wants_me_alive?

        master.logger.info("Main loop ended. Dying")
      end.start
    CODE

    int_server
    log = File.read("preforker.log")
    log.should_not =~ /Main loop ended. Dying/
  end

  sandboxed_it "should add a worker on ttin" do
    run_preforker <<-CODE
      Preforker.new(:workers => 2) do |master|
        sleep 0.1 while master.wants_me_alive?
      end.start
    CODE

    signal_server(:TTIN)
    sleep 0.5
    log = File.read("preforker.log")
    log.scan(/Child.*Created/).size.should == 3
  end

  sandboxed_it "should remove a worker on ttou" do
    run_preforker <<-CODE
      Preforker.new(:workers => 2) do |master|
        sleep 0.1 while master.wants_me_alive?
      end.start
    CODE

    signal_server(:TTOU)
    sleep 0.5
    log = File.read("preforker.log")
    log.scan(/Child.*Exiting/).size.should == 1
  end

  sandboxed_it "should remove all workers on winch" do
    run_preforker <<-CODE
      Preforker.new(:workers => 2) do |master|
        sleep 0.1 while master.wants_me_alive?
      end.start
    CODE

    signal_server(:WINCH)
    sleep 0.5
    log = File.read("preforker.log")
    log.scan(/Child.*Exiting/).size.should == 2
  end

  sandboxed_it "should keep creating workers when they die" do
    run_preforker <<-CODE
      Preforker.new(:workers => 1, :timeout => 0.2) do |master|
      end.start
    CODE

    sleep 0.3
    log = File.read("preforker.log")
    log.scan(/Child.*Created/).size.should > 1
  end
end
