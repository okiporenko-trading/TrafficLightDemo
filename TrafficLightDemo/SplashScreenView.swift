import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        VStack(spacing: 40) {
            Text("Traffic Light Demo")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.black)
            
            VStack(spacing: 30) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .fill(Color(red: 1, green: 0.784, blue: 0))
                    .frame(width: 60, height: 60)
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 60, height: 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.588, green: 0.706, blue: 0.902))
    }
}

#Preview {
    SplashScreenView()
}
