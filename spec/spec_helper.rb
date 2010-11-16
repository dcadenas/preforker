$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'preforker'
require 'spec'
require 'spec/autorun'
require 'rubygems'
require 'file_test_helper'

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f}

include Integration
Spec::Runner.configure do |config|
end
