module CFnDK
  module CredentialResolvable
    private

    def resolve_credential(data, option)
      global_config = CFnDK::GlobalConfig.new(data, option)
      CFnDK::CredentialProviderChain.new(global_config.profile).resolve
    end
  end
end
