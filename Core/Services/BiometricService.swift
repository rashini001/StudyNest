internal import LocalAuthentication
import Foundation

final class BiometricService {

    static let shared = BiometricService()

    /// Returns the biometric type available on this device (.faceID, .touchID, or .none)
    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        return context.biometryType
    }

    /// True when Face ID / Touch ID is enrolled and available.
    var isBiometricsAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate(reason: String) async -> Bool {
#if targetEnvironment(simulator)
        // Simulator has no real Face ID hardware.
        // To test: Simulator menu → Features → Face ID → Enrolled,
        // then trigger with Features → Face ID → Matching Face.
        // We auto-pass here so the vault UI is reachable during development.
        return true
#else
        let context = LAContext()
        // Hide the "Enter Passcode" fallback — Face ID only.
        context.localizedFallbackTitle = ""

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                        error: &error) else {
            return false
        }

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
