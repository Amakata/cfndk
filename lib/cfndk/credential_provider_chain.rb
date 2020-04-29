module CFnDK
  class CredentialProviderChain
    def initialize(profile = nil)
      @profile = profile
    end

    def resolve
      providers.each do |method_name, options|
        CFnDK.logger.debug "resolving: #{method_name}"
        provider = send(method_name, options)
        CFnDK.logger.debug "resolved: #{method_name}" if provider && provider.set?
        return provider if provider && provider.set?
      end
      nil
    end

    private

    def providers
      [
        [:env_credentials, {}],
        [:assume_role_credentials, {}],
        [:shared_credentials, {profile: @profile}],
        [:instance_profile_credentials, {
          retries: 0,
          http_open_timeout: 1,
          http_read_timeout: 1,
        }],
      ]
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
      if options[:profile]
        ::Aws::SharedCredentials.new(profile_name: options[:profile])
      else
        ::Aws::SharedCredentials.new(
          profile_name: ENV['AWS_PROFILE'].nil? ? 'default' : ENV['AWS_PROFILE'])
      end
    rescue ::Aws::Errors::NoSuchProfileError
      nil
    end

    def assume_role_credentials(options)
      if ::Aws.shared_config.config_enabled?
        profile = nil
        region = nil
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
        chain_config: nil
      )
    end
  end
end
