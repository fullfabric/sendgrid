require 'rubygems'
require 'pry-debugger'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'action_mailer'
require 'sendgrid'

ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true