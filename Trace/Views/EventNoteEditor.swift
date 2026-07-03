import SwiftUI

struct EventNoteEditor: View {
    let eventTitle: String
    @Binding var noteText: String
    let onCancel: () -> Void
    let onSave: () -> Void
    @FocusState private var isNoteFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(eventTitle)
                        .font(.title2.weight(.semibold))

                    Text("Event note")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $noteText)
                    .focused($isNoteFocused)
                    .frame(minHeight: 180)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if noteText.isEmpty {
                            Text("What should you remember about this event?")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }

                Text("Saving an empty note removes it from the event.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done") {
                        isNoteFocused = false
                    }
                }
            }
            .onAppear {
                isNoteFocused = true
            }
        }
    }
}

struct EventDateTimeEditor: View {
    let eventTitle: String
    @Binding var loggedAt: Date
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(eventTitle)
                        .font(.title2.weight(.semibold))

                    Text("Logged date and time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                DatePicker(
                    "Date & Time",
                    selection: $loggedAt,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Moving an event updates Calendar, Home, and Statistics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Date & Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var noteText = ""

    EventNoteEditor(eventTitle: "Headache", noteText: $noteText) {} onSave: {}
}
