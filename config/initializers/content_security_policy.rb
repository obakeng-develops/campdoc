Rails.application.configure do
  config.content_security_policy do |policy|
    remote_sources = [ ENV["STORAGE_ENDPOINT"], ENV["STORAGE_BROWSER_ORIGIN"] ].compact_blank

    policy.default_src :self
    policy.base_uri :self
    policy.connect_src :self, *remote_sources
    policy.font_src :self
    policy.form_action :self
    policy.frame_ancestors :none
    policy.img_src :self, :data, :blob, *remote_sources
    policy.object_src :none
    policy.script_src :self
    policy.style_src :self
  end

  config.content_security_policy_nonce_generator = ->(*) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_nonce_auto = true
end
