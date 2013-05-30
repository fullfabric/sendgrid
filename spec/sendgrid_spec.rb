require 'spec_helper'

describe SendGrid do

  class ActionMailerWithSendgrid < ActionMailer::Base

    include SendGrid

    def email_method_under_test

      mail( from: "Bob Sacamento <bob@example.com>", to: [ "Cosmo Kramer <kramer@example.com>" ], subject: "Cat-fight" )

    end

  end

  context "class-level options" do

    it "sets a default category to be applied to all emails" do

      class ClassUnderTest < ActionMailerWithSendgrid
        sendgrid_category "category_1"
      end

      mail    = ClassUnderTest.email_method_under_test
      headers = JSON.parse( mail[ 'X-SMTPAPI' ].value )

      expect( headers['category'] ).to eq "category_1"

    end

  end

  context "instance-level options" do

    it "sets a category" do

      class_under_test = Class.new( ActionMailerWithSendgrid ) do

        def email_method_under_test
          sendgrid_category "category_1"
          super
        end

      end

      mail    = class_under_test.email_method_under_test
      expect( mail[ 'X-SMTPAPI' ].value ).to include '"category": "category_1"'

    end

    it "sets unique arguments" do

      class_under_test = Class.new( ActionMailerWithSendgrid ) do

        def email_method_under_test
          sendgrid_unique_args( { campaign_id: 12345 } )
          super
        end

      end

      mail    = class_under_test.email_method_under_test
      expect( mail[ 'X-SMTPAPI' ].value ).to include '"unique_args": {"campaign_id":12345}'

    end

  end

  it "requires a sender" do

    class_under_test = Class.new( ActionMailerWithSendgrid ) do

      def email_method_under_test

        options = {
          to: [ "Cosmo Kramer <kramer@example.com>" ],
          subject: "Cat-fight"
        }

        mail options

      end

    end

    expect{ class_under_test.email_method_under_test }.to raise_error( ArgumentError )

  end

  it "requires at least one recipient" do

    class_under_test = Class.new( ActionMailerWithSendgrid ) do

      def email_method_under_test

        options = {
          from: "Bob Sacamento <bob@example.com>",
          subject: "Cat-fight"
        }

        mail options

      end

    end

    expect{ class_under_test.email_method_under_test }.to raise_error( ArgumentError )

  end

  it "passes all the recipients in the sengrid specific header so that sendgrid remove the addresses from the to header" do

    class_under_test = Class.new( ActionMailerWithSendgrid ) do

      def email_method_under_test

        options = {
          to: [ "Cosmo Kramer <kramer@example.com>", "Newman <newman@example.com>" ],
          from: "Bob Sacamento <bob@example.com>",
          subject: "Cat-fight"
        }

        mail options

      end
    end

    mail    = class_under_test.email_method_under_test
    expect( mail[ 'X-SMTPAPI' ].value ).to include '"to": ["kramer@example.com", "newman@example.com"]'

  end

  context "substitutions" do

    it "sets the substitution tags" do

      class_under_test = Class.new( ActionMailerWithSendgrid ) do

        def email_method_under_test

          sendgrid_substitute "|first_name|", [ "Cosmo", "Newman" ]
          sendgrid_substitute "|last_name|",  [ "Kramer", nil ]

          options = {
            to: [ "Cosmo Kramer <kramer@example.com>", "Newman <newman@example.com>" ],
            from: "Bob Sacamento <bob@example.com>",
            subject: "Cat-fight"
          }

          mail options

        end

      end

      mail    = class_under_test.email_method_under_test
      expect( mail[ 'X-SMTPAPI' ].value ).to include '"sub": {"|first_name|": ["Cosmo", "Newman"], "|last_name|": ["Kramer",null]}'

    end

    it "requires the number of substitutions to equal the number of recipients" do

      class_under_test = Class.new( ActionMailerWithSendgrid ) do

        def email_method_under_test

          sendgrid_substitute "|first_name|", [ "Cosmo" ]

          options = {
            to: [ "Cosmo Kramer <kramer@example.com>", "Newman <newman@example.com>" ],
            from: "Bob Sacamento <bob@example.com>",
            subject: "Cat-fight"
          }

          mail options

        end

      end

      expect{ class_under_test.email_method_under_test }.to raise_error( ArgumentError )

    end

  end

end