guard 'rspec', all_after_pass: false, all_on_start: false, cli: "-fd" do

  watch( %r{^spec/.+_spec\.rb$} )
  watch( 'lib/sendgrid.rb' )      { "spec/sendgrid_spec.rb" }
  watch( 'spec/spec_helper.rb' )  { "spec" }

end