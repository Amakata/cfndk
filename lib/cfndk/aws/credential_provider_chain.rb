module CFnDK
  module Aws
    class CredentialProviderChain
      def initialize(config = nil)
        @config = config
      end

      def resolve
        providers.each do |method_name, options|
          provider = send(method_name, options.merge(config: @config))
          return provider if provider && provider.set?
        end
        nil
      end

      private

      def providers
        [
          [:static_credentials, {}],
          [:env_credentials, {}],
          [:assume_role_credentials, {}],
          [:shared_credentials, {}],
          [:process_credentials, {}],
          [:instance_profile_credentials, {
            retries: @config ? @config.instance_profile_credentials_retries : 0,
            http_open_timeout: @config ? @config.instance_profile_credentials_timeout : 1,
            http_read_timeout: @config ? @config.instance_profile_credentials_timeout : 1,
          }],
        ]
      end

      def static_credentials(options)
        if options[:config]
          ::Aws::Credentials.new(
            options[:config].access_key_id,
            options[:config].secret_access_key,
            options[:config].session_token)
        else
          nil
        end
      end

      def env_credentials(options)
        key =    %w(AWS_ACCESS_KEY_ID AMAZON_ACCESS_KEY_ID AWS_ACCESS_KEY)
        secret = %w(AWS_SECRET_ACCESS_KEY AMAZON_SECRET_ACCESS_KEY AWS_SECRET_KEY)
        token =  %w(AWS_SESSION_TOKEN AMAZON_SESSION_TOKEN)
        ::Aws::Credentials.new(envar(key), envar(secret), envar(token))
      end

      def envar(keys)
        keys.each do |key|
          return ENV[key] if ENV.key?(key)
        end
        nil
      end

      def shared_credentials(options)
        if options[:config]
          ::Aws::SharedCredentials.new(profile_name: options[:config].profile)
        else
          ::Aws::SharedCredentials.new(
            profile_name: ENV['AWS_PROFILE'].nil? ? 'default' : ENV['AWS_PROFILE'])
        end
      rescue ::Aws::Errors::NoSuchProfileError
        nil
      end

      def process_credentials(options)
        profile_name = options[:config].profile if options[:config]
        profile_name ||= ENV['AWS_PROFILE'].nil? ? 'default' : ENV['AWS_PROFILE']

        config = ::Aws.shared_config
        if config.config_enabled? && process_provider = config.credentials_process(profile_name)
          ::Aws::ProcessCredentials.new(process_provider)
        else
          nil
        end
      rescue ::Aws::Errors::NoSuchProfileError
        nil
      end

      def assume_role_credentials(options)
        if ::Aws.shared_config.config_enabled?
          profile = nil
          region = nil
          if options[:config]
            profile = options[:config].profile
            region = options[:config].region
            assume_role_with_profile(options[:config].profile, options[:config].region)
          end
          assume_role_with_profile(profile, region)
        else
          nil
        end
      end

      def instance_profile_credentials(options)
        if ENV['AWS_CONTAINER_CREDENTIALS_RELATIVE_URI']
          ::Aws::ECSCredentials.new(options)
        else
          ::Aws::InstanceProfileCredentials.new(options)
        end
      end

      def assume_role_with_profile(prof, region)
        ::Aws.shared_config.assume_role_credentials_from_config(
          profile: prof,
          region: region,
          chain_config: @config
        )
      end
    end
  end
end
