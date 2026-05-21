import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack(alignment: .bottom) {

            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }

                CalendarView()
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }

                Color.clear
                    .tabItem {
                        Label("", systemImage: "")
                    }

                StatisticsView()
                    .tabItem {
                        Label("Statistics", systemImage: "chart.bar")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }

            Button {
                print("Add event")
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 6)
            }
            .offset(y: -10)
        }
    }
}

#Preview {
    ContentView()
}
