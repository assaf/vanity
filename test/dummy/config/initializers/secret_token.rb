# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
Dummy::Application.config.secret_token = '33ccbc9a29f3b02e87c08904505b1c9a3a1e97dd01f02e598e65ee9e7b96fff2ca4a6d0dd7c4a8d3682d8c64f84d372661e141264e70697dc576c722c72d80d0'
Dummy::Application.config.secret_key_base = 'secret' if Dummy::Application.config.respond_to?(:secret_key_base=)