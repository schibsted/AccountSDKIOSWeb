./cuckoo/run generate --testable AccountSDKIOSWeb \
  --output Tests/AccountSDKIOSWebTests/GeneratedMocks.swift \
  Sources/AccountSDKIOSWeb/HTTP/HTTPClient.swift \
  Sources/AccountSDKIOSWeb/Storage/SessionStorage.swift \
  Sources/AccountSDKIOSWeb/Storage/Keychain/Compat/LegacyKeychainTokenStorage.swift
