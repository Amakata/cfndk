module CFnDK
  module CredentialResolvable
    private

    def resolve_credential(data, option)
      global_config = CFnDK::GlobalConfig.new(data, option)
      config = OpenStruct.new
      config.profile = global_config.profile
      CFnDK::CredentialProviderChain.new(config).resolve
    end
  end
end
