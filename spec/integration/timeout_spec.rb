require 'spec_helper'

include FileTestHelper
describe "Preforker" do
  sandboxed_it "should not respawn workers when there's not a timeout" do
    run_preforker <<-CODE
      Preforker.new(:timeout => 2, :workers => 1) do |master|
        sleep 0.1 while master.wants_me_alive?
      end.start
    CODE

    sleep 1
    term_server
    log = File.read("preforker.log")
    log.should_not =~ /ERROR.*timeout/
    log.scan(/Child.*Created/).size.should == 1
  end

  sandboxed_it "should respawn workers when there's a timeout (master checks once a second max)" do
    run_preforker <<-CODE
      Preforker.new(:timeout => 1, :workers => 1) do
        sleep 1000
      end.start
    CODE

    sleep 1
    term_server
    log = File.read("preforker.log")
    log.should =~ /ERROR.*timeout/
    log.scan(/Child.*Created/).size.should > 1
  end
end
