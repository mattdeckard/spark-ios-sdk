
import Foundation
import KeychainAccess

class SparkInstance {
    private static var actualSharedInstance: SparkInstance?
    
    private static let clientIdKey = "clientIdKey"
    private static let clientSecretKey = "clientSecretKey"
    private static let scopeKey = "scopeKey"
    private static let redirectUriKey = "redirectUriKey"
    private static let simpleAccessTokenKey = "simpleAccessTokenKey"
    
    static var sharedInstance: SparkInstance {
        get {
            if actualSharedInstance == nil {
                Logger.warn("Detected use of deprecated SparkSDK API.")
                let actualSharedInstance = SparkInstance()
       
                let keychain = getKeychain()
                do {
                    if let clientId = try keychain.get(clientIdKey),
                        let clientSecret = try keychain.get(clientSecretKey),
                        let scope = try keychain.get(scopeKey),
                        let redirectUri = try keychain.get(redirectUriKey) {
                        let clientAccount = ClientAccount(clientId: clientId, clientSecret: clientSecret)
                        let oauthStrategy = OAuthStrategy(clientAccount: clientAccount, scope: scope, redirectUri: redirectUri)
                        actualSharedInstance.set(authenticationStrategy: oauthStrategy)
                    } else if let simpleAccessToken = try keychain.get(simpleAccessTokenKey) {
                        actualSharedInstance.set(authenticationStrategy: SimpleAuthStrategy(accessToken: simpleAccessToken))
                    }
                } catch let error {
                    Logger.error("Failed to get global authentication strategy information", error: error)
                }
                
                self.actualSharedInstance = actualSharedInstance
            }
            return actualSharedInstance!
        }
    }
    
    static func saveGlobalOAuth(clientId: String, clientSecret: String, scope: String, redirectUri: String) {
        clearGlobalAuthenticationStrategyInformation()
        let keychain = getKeychain()
        do {
            try keychain.set(clientId, key: clientIdKey)
            try keychain.set(clientSecret, key: clientSecretKey)
            try keychain.set(scope, key: scopeKey)
            try keychain.set(redirectUri, key: redirectUriKey)
        } catch let error {
            Logger.error("Failed to save global OAuth information", error: error)
        }
    }
    
    static func saveGlobalSimpleAccessToken(_ simpleAccessToken: String) {
        clearGlobalAuthenticationStrategyInformation()
        let keychain = getKeychain()
        do {
            try keychain.set(simpleAccessToken, key: simpleAccessTokenKey)
        } catch let error {
            Logger.error("Failed to save global simple access token", error: error)
        }
    }
    
    static func clearGlobalAuthenticationStrategyInformation() {
        let keychain = getKeychain()
        do {
            try keychain.remove(clientIdKey)
            try keychain.remove(clientSecretKey)
            try keychain.remove(scopeKey)
            try keychain.remove(redirectUriKey)
            try keychain.remove(simpleAccessTokenKey)
        } catch let error {
            Logger.error("Failed to clear global authentication strategy information", error: error)
        }
    }
    
    private static func getKeychain() -> Keychain {
        return Keychain(service: "\(Bundle.main.bundleIdentifier ?? "").sparksdk.deprecated.global")
    }
    
    let authenticationStrategy: AuthenticationStrategyProxy
    let callMetrics: CallMetrics
    let phone: Phone
    
    init() {
        authenticationStrategy = AuthenticationStrategyProxy()
        let deviceService = DeviceService(authenticationStrategy: authenticationStrategy)
        callMetrics = CallMetrics(authenticationStrategy: authenticationStrategy, deviceService: deviceService)
        let callManager = CallManager(authenticationStrategy: authenticationStrategy, deviceService: deviceService)
        let webSocketService = WebSocketService(authenticationStrategy: authenticationStrategy, callManager: callManager)
        let applicationLifecycleObserver = ApplicationLifecycleObserver(webSocketService: webSocketService, callManager: callManager, deviceService: deviceService)
        phone = Phone(authenticationStrategy: authenticationStrategy, applicationLifecycleObserver: applicationLifecycleObserver, webSocketService: webSocketService, callManager: callManager, deviceService: deviceService)
    }
    
    func set(authenticationStrategy: AuthenticationStrategy) {
        self.authenticationStrategy.setDelegateStrategy(authenticationStrategy)
    }
}