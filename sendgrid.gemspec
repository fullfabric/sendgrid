$:.push File.expand_path("../lib", __FILE__)
require 'sendgrid/version'

Gem::Specification.new do |s|

  s.name = "sendgrid"
  s.version = SendGrid::VERSION
  s.authors = [ "Stephen Blankenship", "Marc Tremblay", "Bob Burbach", "Drew Tempelmeyer", "Luis Correa d'Almeida" ]
  s.date = "2013-05-30"
  s.description = "This gem allows simple integration between ActionMailer and SendGrid. \n                         SendGrid is an email deliverability API that is affordable and has lots of bells and whistles."
  s.email = "luis@fullfabric.com"

  s.extra_rdoc_files = [
    "LICENSE",
    "README.md"
  ]

  s.required_rubygems_version = ">= 1.3.6"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test}/*`.split("\n")

  s.require_paths = ["lib"]

  s.homepage = "https://github.com/fullfabric/sendgrid"
  s.summary = "A gem that allows simple integration of ActionMailer with SendGrid (http://sendgrid.com)"

  s.add_runtime_dependency 'rails', '>= 3.0'
  s.add_development_dependency 'shoulda', '>= 0'
  s.add_development_dependency 'rspec', '>= 0'
  s.add_development_dependency 'guard-rspec', '>= 0'
  s.add_development_dependency 'pry-debugger', '>= 0'

end

