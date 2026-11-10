import SwiftUI

struct TaskEditor: View {
    @State var draft: TaskDraft
    let onSave: (PlannedTask) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                if draft.isNew {
                    Text("New Task")
                } else {
                    Text("Edit Task")
                }
            }
            .font(.headline)

            Form {
                TextField("Title", text: $draft.title)
                TextField("Note", text: $draft.note, axis: .vertical)
                    .lineLimit(2...4)
                Picker("Start", selection: $draft.startSlot) {
                    ForEach(0..<TaskDraft.slotsPerDay, id: \.self) { slot in
                        Text(verbatim: timeLabel(slot)).tag(slot)
                    }
                }
                Picker("End", selection: $draft.endSlot) {
                    ForEach(1...TaskDraft.slotsPerDay, id: \.self) { slot in
                        Text(verbatim: timeLabel(slot)).tag(slot)
                    }
                }
                Picker("Category", selection: $draft.lane) {
                    ForEach(TaskLane.allCases) { lane in
                        Text(lane.title).tag(lane)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                if let onDelete {
                    Button("Delete", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(draft.makeTask())
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.isValid)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onChange(of: draft.startSlot) { _, newValue in
            if draft.endSlot <= newValue {
                draft.endSlot = min(newValue + 1, TaskDraft.slotsPerDay)
            }
        }
    }

    private func timeLabel(_ slot: Int) -> String {
        draft.slotDate(slot).formatted(date: .omitted, time: .shortened)
    }
}
