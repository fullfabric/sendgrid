require 'json'
# require 'sendgrid/railtie'

module SendGrid

  # By default, all options are disabled, and sendgrid is a plain old SMTP server

  VALID_OPTIONS = [
    :opentrack,
    :clicktrack,
    :ganalytics,
    :gravatar,
    :subscriptiontrack,
    :footer,
    :spamcheck,
    :bypass_list_management
  ]

  VALID_GANALYTICS_OPTIONS = [
    :utm_source,
    :utm_medium,
    :utm_campaign,
    :utm_term,
    :utm_content
  ]

  DEBUG = false

  def self.included(base)

    base.class_eval do

      class << self

        attr_accessor :default_sg_category,
                      :default_sg_options,
                      :default_sg_subscriptiontrack_text,
                      :default_sg_footer_text,
                      :default_sg_spamcheck_score,
                      :default_sg_unique_args
      end

      # attr_accessor :sg_category,
      #               :sg_options,
      #               :sg_disabled_options,
      #               :sg_recipients,
      #               :sg_substitutions,
      #               :sg_subscriptiontrack_text,
      #               :sg_footer_text,
      #               :sg_spamcheck_score,
      #               :sg_unique_args

    end

    # NOTE: This commented-out approach may be a "safer" option for Rails 3, but it
    # would cause the headers to get set during delivery, and not when the message is initialized.
    #
    # If base supports register_interceptor (i.e., Rails 3 ActionMailer), use it...
    # if base.respond_to?(:register_interceptor)
    #   base.register_interceptor(SendgridInterceptor)
    # end

    base.extend(ClassMethods)

  end

  module ClassMethods

    # Sets a default category for all emails.
    # :use_subject_lines has special behavior that uses the subject-line of
    # each outgoing email for the SendGrid category. This special behavior
    # can still be overridden by calling sendgrid_category from within a
    # mailer method.
    def sendgrid_category category
      self.default_sg_category = category
    end

    # Enables a default option for all emails.
    # See documentation for details.
    #
    # Supported options:
    # * :opentrack
    # * :clicktrack
    # * :ganalytics
    # * :gravatar
    # * :subscriptiontrack
    # * :footer
    # * :spamcheck
    def sendgrid_enable *options
      self.default_sg_options = Array.new unless self.default_sg_options
      options.each { |option| self.default_sg_options << option if VALID_OPTIONS.include?(option) }
    end

    def sendgrid_disable *options
      self.default_sg_options = Array.new unless self.default_sg_options
      options.each { |option| self.default_sg_options.delete option }
    end

    # Sets the default text for subscription tracking (must be enabled).
    # There are two options:
    # 1. Add an unsubscribe link at the bottom of the email
    #   {:html => "Unsubscribe <% here %>", :plain => "Unsubscribe here: <% %>"}
    # 2. Replace given text with the unsubscribe link
    #   {:replace => "<unsubscribe_link>" }
    def sendgrid_subscriptiontrack_text texts
      self.default_sg_subscriptiontrack_text = texts
    end

    # Sets the default footer text (must be enabled).
    # Should be a hash containing the html/plain text versions:
    #   {:html => "html version", :plain => "plan text version"}
    def sendgrid_footer_text texts
      self.default_sg_footer_text = texts
    end

    # Sets the default spamcheck score text (must be enabled).
    def sendgrid_spamcheck_maxscore score
      self.default_sg_spamcheck_score = score
    end

    # Sets unique args at the class level. Should be a hash
    # of name, value pairs.
    #   { :some_unique_arg => "some_value"}
    def sendgrid_unique_args unique_args = {}
      self.default_sg_unique_args = unique_args
    end

  end

  # Call within mailer method to override the default value.
  def sendgrid_category category
    @sg_category = category
  end

  # Call within mailer method to set unique args for this email.
  # Merged with class-level unique args, if any exist.
  def sendgrid_unique_args unique_args = {}
    @sg_unique_args = unique_args
  end

  # Call within mailer method to add an option not in the defaults.
  def sendgrid_enable *options
    @sg_options = Array.new unless @sg_options
    options.each { |option| @sg_options << option if VALID_OPTIONS.include?(option) }
  end

  # Call within mailer method to remove one of the defaults.
  def sendgrid_disable *options
    @sg_disabled_options = Array.new unless @sg_disabled_options
    options.each { |option| @sg_disabled_options << option if VALID_OPTIONS.include?(option) }
  end

  # # Call within mailer method to add an array of recipients
  # def sendgrid_recipients emails
  #   raise ArgumentError.new( "recipients need to be an array" ) unless emails.is_a?( Array )
  #   @sg_recipients = emails
  # end

  # Call within mailer method to add an array of substitions
  # NOTE: you must ensure that the length of the substitions equals the
  #       length of the sendgrid_recipients.
  def sendgrid_substitute placeholder, subs
    @sg_substitutions = Hash.new unless @sg_substitutions
    @sg_substitutions[placeholder] = subs
  end

  # Call within mailer method to override the default value.
  def sendgrid_subscriptiontrack_text texts
    @sg_subscriptiontrack_text = texts
  end

  # Call within mailer method to override the default value.
  def sendgrid_footer_text texts
    @sg_footer_text = texts
  end

  # Call within mailer method to override the default value.
  def sendgrid_spamcheck_maxscore score
    @sg_spamcheck_score = score
  end

  # Call within mailer method to set custom google analytics options
  # http://sendgrid.com/documentation/appsGoogleAnalytics
  def sendgrid_ganalytics_options options
    @sg_ganalytics_options = []
    options.each { |option| @sg_ganalytics_options << option if VALID_GANALYTICS_OPTIONS.include?(option[0].to_sym) }
  end

  def sendgrid_anonymize_recipients
    @sg_publicize_recipients = false
  end

  # Call this if you require email addresses to show in
  # to, cc and bcc fields. This is also required for cc
  # and bcc addresses to receive the email.
  def sendgrid_publicize_recipients
    @sg_publicize_recipients = true
  end

  protected

    # Sets the custom X-SMTPAPI header after creating the email but before delivery
    def mail params = {}, &block

      raise ArgumentError.new( "sender required" ) unless params[ :from ].present?
      raise ArgumentError.new( ":to needs to be an array" ) unless params[ :to ].present? && params[ :to ].is_a?( Array )
      raise ArgumentError.new( "at least one recipient required" ) unless params[ :to ].size > 0

      # binding.pry

      super.tap do |message|

        ensure_substitutions_match_recipients! params

        # Setting the headers on the Mailer class rather than on the Mail message as
        # per the documentation of ActionMailer::Base
        # http://api.rubyonrails.org/classes/ActionMailer/Base.html#method-i-headers
        self.headers['X-SMTPAPI'] = headers_as_json_for_sendgrid message

      end

    end

  private

    def ensure_substitutions_match_recipients! headers

      if @sg_substitutions && !@sg_substitutions.empty?
        @sg_substitutions.each do |find, replace|
          raise ArgumentError.new("Array for #{find} is not the same size as the recipient array") if replace.size != headers[ :to ].size
        end
      end

    end

    def prepare_recipients sendgrid_headers_options

      anonymize_recipients sendgrid_headers_options unless @sg_publicize_recipients
      sendgrid_headers_options

    end

    # this ensures recipients get removed from the to, cc and bcc headers
    def anonymize_recipients sendgrid_headers_options
      sendgrid_headers_options[ :to ] = message.to.to_a
    end

    def build_unique_args_headers sendgrid_headers_options

      @sg_unique_args = @sg_unique_args || {}

      if @sg_unique_args || self.class.default_sg_unique_args

        unique_args = self.class.default_sg_unique_args || {}
        unique_args = unique_args.merge @sg_unique_args

        sendgrid_headers_options[ :unique_args ] = unique_args unless unique_args.empty?

      end

      sendgrid_headers_options

    end

    def build_category_headers sendgrid_headers_options

      if @sg_category && @sg_category == :use_subject_lines

        sendgrid_headers_options[ :category ] = message.subject

      elsif @sg_category

        sendgrid_headers_options[ :category ] = @sg_category

      elsif self.class.default_sg_category && self.class.default_sg_category.to_sym == :use_subject_lines

        sendgrid_headers_options[ :category ] = message.subject

      elsif self.class.default_sg_category

        sendgrid_headers_options[ :category ] = self.class.default_sg_category

      end

      sendgrid_headers_options

    end

    def build_substitutions_headers sendgrid_headers_options

      sendgrid_headers_options[ :sub ] = @sg_substitutions if @sg_substitutions && !@sg_substitutions.empty?
      sendgrid_headers_options

    end

    def build_options_headers sendgrid_headers_options

      enabled_opts = []

      if @sg_options && !@sg_options.empty?

        # merge the options so that the instance-level "overrides"
        merged = self.class.default_sg_options || []
        merged += @sg_options
        enabled_opts = merged

      elsif self.class.default_sg_options

        enabled_opts = self.class.default_sg_options

      end

      if !enabled_opts.empty? || (@sg_disabled_options && !@sg_disabled_options.empty?)

        filters = filters_hash_from_options(enabled_opts, @sg_disabled_options)
        sendgrid_headers_options[:filters] = filters if filters && !filters.empty?

      end

      sendgrid_headers_options

    end

    def headers_as_json_for_sendgrid message

      sendgrid_headers_options = {}

      prepare_recipients sendgrid_headers_options

      build_unique_args_headers   sendgrid_headers_options
      build_category_headers      sendgrid_headers_options
      build_substitutions_headers sendgrid_headers_options
      build_options_headers       sendgrid_headers_options

      # clean up json
      sendgrid_headers_options.to_json.gsub(/(["\]}])([,:])(["\[{])/, '\\1\\2 \\3')

    end




    def filters_hash_from_options enabled_opts, disabled_opts

      filters = {}

      enabled_opts.each do |opt|
        filters[opt] = {'settings' => {'enable' => 1}}
        case opt.to_sym
          when :subscriptiontrack
            if @sg_subscriptiontrack_text
              if @sg_subscriptiontrack_text[:replace]
                filters[:subscriptiontrack]['settings']['replace'] = @sg_subscriptiontrack_text[:replace]
              else
                filters[:subscriptiontrack]['settings']['text/html'] = @sg_subscriptiontrack_text[:html]
                filters[:subscriptiontrack]['settings']['text/plain'] = @sg_subscriptiontrack_text[:plain]
              end
            elsif self.class.default_sg_subscriptiontrack_text
              if self.class.default_sg_subscriptiontrack_text[:replace]
                filters[:subscriptiontrack]['settings']['replace'] = self.class.default_sg_subscriptiontrack_text[:replace]
              else
                filters[:subscriptiontrack]['settings']['text/html'] = self.class.default_sg_subscriptiontrack_text[:html]
                filters[:subscriptiontrack]['settings']['text/plain'] = self.class.default_sg_subscriptiontrack_text[:plain]
              end
            end

          when :footer
            if @sg_footer_text
              filters[:footer]['settings']['text/html'] = @sg_footer_text[:html]
              filters[:footer]['settings']['text/plain'] = @sg_footer_text[:plain]
            elsif self.class.default_sg_footer_text
              filters[:footer]['settings']['text/html'] = self.class.default_sg_footer_text[:html]
              filters[:footer]['settings']['text/plain'] = self.class.default_sg_footer_text[:plain]
            end

          when :spamcheck
            if self.class.default_sg_spamcheck_score || @sg_spamcheck_score
              filters[:spamcheck]['settings']['maxscore'] = @sg_spamcheck_score || self.class.default_sg_spamcheck_score
            end

          when :ganalytics
            if @sg_ganalytics_options
              @sg_ganalytics_options.each do |key, value|
                filters[:ganalytics]['settings'][key.to_s] = value
              end
            end
        end
      end

      if disabled_opts
        disabled_opts.each do |opt|
          filters[opt] = {'settings' => {'enable' => 0}}
        end
      end

      return filters

    end

end
