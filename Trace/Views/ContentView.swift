import SwiftUI
import UIKit

struct ContentView: View {
    @State private var isShowingQuickLog = false

    private let recentCategories = [
        QuickLogCategory(name: "Mood", icon: "face.smiling", color: .yellow, recentItems: ["Calm", "Focused", "Tired"]),
        QuickLogCategory(name: "Health", icon: "heart.text.square", color: .red, recentItems: ["Headache", "Sleep", "Medication"]),
        QuickLogCategory(name: "Workout", icon: "figure.run", color: .green, recentItems: ["Run", "Walk", "Stretch"]),
        QuickLogCategory(name: "Learning", icon: "book", color: .indigo, recentItems: ["SwiftUI", "Reading", "Course"])
    ]

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
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isShowingQuickLog = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 6)
            }
            .accessibilityLabel("Log event")
            .offset(y: -10)
        }
        .sheet(isPresented: $isShowingQuickLog) {
            QuickLogCategorySheet(categories: recentCategories)
                .presentationDetents([.height(360), .medium])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct QuickLogCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let recentItems: [String]
}

private struct QuickLogCategorySheet: View {
    let categories: [QuickLogCategory]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategoryIndex = 0
    @State private var isShowingCategoryManagement = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TabView(selection: $selectedCategoryIndex) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        categoryPage(category)
                            .tag(index)
                            .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 230)

                Button {
                    isShowingCategoryManagement = true
                } label: {
                    Label("Manage Categories", systemImage: "slider.horizontal.3")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            .navigationTitle("Log Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $isShowingCategoryManagement) {
                CategoriesView()
            }
        }
    }

    private func categoryPage(_ category: QuickLogCategory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(category.color)
                    .frame(width: 44, height: 44)
                    .background(category.color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(category.name)
                    .font(.title2.weight(.semibold))

                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                ForEach(category.recentItems, id: \.self) { item in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Text(item)
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(category.color)
                    .accessibilityLabel("Log \(item)")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    ContentView()
}
