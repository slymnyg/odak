import SwiftUI

/// Asked once, on the first morning: working hours and the breaks that are always there.
/// Reachable again from the planning sheet.
struct RoutineEditor: View {
    @Environment(AppModel.self) private var model
    let isFirstRun: Bool
    let onDone: () -> Void

    @State private var draft = DayRoutine()
    @AppStorage(Preferences.Key.planDay) private var planDay = Preferences.Default.planDay
    @AppStorage(Preferences.Key.planDayMinutes) private var planDayMinutes = Preferences.Default.planDayMinutes
    @AppStorage(Preferences.Key.taskReminderLead) private var reminderLead = Preferences.Default.taskReminderLead

    var body: some View {
        let title: LocalizedStringKey = isFirstRun ? "First, your usual day" : "Day Routine"
        let done: LocalizedStringKey = isFirstRun ? "Continue" : "Done"
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(OdakPalette.ink)
                Text("Set this once. Every morning Odak puts your breaks in place and fits your tasks around them.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OdakPalette.ink.opacity(0.55))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    group("Working hours") {
                        row {
                            Text("I work from")
                            MinutePicker(minutes: $draft.workStart)
                            Text("to")
                            MinutePicker(minutes: $draft.workEnd)
                            Spacer()
                        }
                    }

                    group("Breaks") {
                        ForEach($draft.blocks) { $block in
                            row {
                                Toggle("", isOn: $block.isOn)
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                    .labelsHidden()
                                TextField("Name", text: $block.title)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                MinutePicker(minutes: $block.start)
                                Text(verbatim: "–")
                                MinutePicker(minutes: $block.end)
                                Button {
                                    draft.blocks.removeAll { $0.id == block.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(OdakPalette.ink.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                                .help(Text("Remove"))
                            }
                            .opacity(block.isOn ? 1 : 0.55)
                        }
                        Button {
                            draft.blocks.append(DayRoutine.Block(title: String(localized: "Break"), start: 15 * 60, end: 15 * 60 + 30))
                        } label: {
                            Label("Add a Break", systemImage: "plus")
                        }
                        .buttonStyle(FooterButtonStyle())
                        .padding(.leading, 4)
                    }

                    group("Reminders") {
                        row {
                            Toggle("", isOn: $planDay)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                            Text("Invite me to plan the day at")
                            MinutePicker(minutes: $planDayMinutes)
                                .disabled(!planDay)
                            Spacer()
                        }
                        row {
                            Text("Remind me of each task")
                            Spacer()
                            ReminderLeadPicker(lead: $reminderLead)
                        }
                    }
                }
                .padding(.top, 22)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.never)

            HStack {
                Spacer()
                Button {
                    model.routine.routine = draft
                    model.routine.confirm()
                    model.refreshReminders()
                    onDone()
                } label: {
                    Text(done)
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(draft.workEnd <= draft.workStart)
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 36)
        .padding(.top, 34)
        .padding(.bottom, 26)
        .onAppear { draft = model.routine.routine }
    }

    private func group(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            content()
        }
    }

    private func row(@ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 10) {
            content()
        }
        .font(.system(size: 14))
        .foregroundStyle(OdakPalette.ink)
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(OdakPalette.face.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// A time of day, held as minutes since midnight.
struct MinutePicker: View {
    @Binding var minutes: Int

    var body: some View {
        DatePicker("", selection: date, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .datePickerStyle(.field)
            .fixedSize()
    }

    private var date: Binding<Date> {
        Binding(
            get: { DialGeometry.date(forDayMinutes: min(max(minutes, 0), 1439), on: .now) },
            set: { minutes = DialGeometry.dayMinutes(for: $0, on: $0) }
        )
    }
}

struct ReminderLeadPicker: View {
    @Binding var lead: Int

    var body: some View {
        Picker("", selection: $lead) {
            ForEach(Preferences.reminderLeads, id: \.self) { lead in
                switch lead {
                case Preferences.noReminder: Text("Never").tag(lead)
                case 0: Text("When it starts").tag(lead)
                default: Text("\(lead) min before").tag(lead)
                }
            }
        }
        .labelsHidden()
        .fixedSize()
    }
}
