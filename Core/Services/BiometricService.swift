internal import LocalAuthentication
import Foundation


final class BiometricService {

    static let shared = BiometricService()
    private init() {}

    
    var isFaceIDAvailable: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                        error: &error) else { return false }
        return context.biometryType == .faceID
        #endif
    }

    func authenticate(reason: String) async -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        let context = LAContext()
        context.localizedFallbackTitle = ""

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                        error: &error),
              context.biometryType == .faceID
        else { return false }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
        #endif
    }
}
