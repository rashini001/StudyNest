
import SwiftUI

struct OfflineBanner: View {

    @ObservedObject private var sync = SyncService.shared

    var body: some View {
        if !sync.isOnline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 12, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("You're offline")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Changes saved locally — will sync when connected")
                        .font(.system(size: 10))
                        .opacity(0.85)
                }
                Spacer()
                if sync.isSyncing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.orange)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: sync.isOnline)
        } else if sync.isSyncing {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.75).tint(.white)
                Text("Syncing…")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.nestPurple)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
