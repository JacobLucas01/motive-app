import SwiftUI

struct LaunchSplashView: View {
    var body: some View {
        ZStack {
            MotiveTheme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Circle()
                    .fill(MotiveTheme.accent)
                    .frame(width: 64, height: 64)

                Text("Motive")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(MotiveTheme.primaryText)
            }
        }
    }
}

struct LaunchSplashView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchSplashView()
    }
}
