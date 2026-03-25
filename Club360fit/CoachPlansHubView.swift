import Auth
import Observation
import SwiftUI

/// Coach-only editor: schedule sessions, workout plans, and meal plans for one client (`Supabase` coach RLS).
/// Opened from the main Hub tab or via navigation with a known `clientId`.
struct CoachPlansHubView: View {
    let clientId: String
    /// Shown until `ClientHomeViewModel` finishes loading member name.
    let displayTitle: String

    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @State private var home = ClientHomeViewModel()

    @State private var tab: CoachPlansHubTab
    @State private var model = CoachPlansHubModel()

    @State private var editingWorkout: WorkoutPlanDTO?
    @State private var editingMeal: MealPlanDTO?
    @State private var editingSchedule: ScheduleEventDTO?
    @State private var showNewWorkout = false
    @State private var showNewMeal = false
    @State private var showNewSchedule = false

    @State private var deleteWorkoutId: String?
    @State private var deleteMealId: String?
    @State private var deleteScheduleId: String?

    init(clientId: String, displayTitle: String, initialTab: CoachPlansHubTab = .schedule) {
        self.clientId = clientId
        self.displayTitle = displayTitle
        _tab = State(initialValue: initialTab)
    }

    private var memberName: String {
        if home.isLoading { return displayTitle }
        return home.welcomeName
    }

    var body: some View {
        Group {
            if clientId.isEmpty {
                ContentUnavailableView("No client", systemImage: "person.crop.circle.badge.xmark")
            } else {
                hubContent
            }
        }
        .navigationTitle("Plans & schedule")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task(id: clientId) {
            await home.loadForClient(clientId: clientId)
            await model.reload(clientId: clientId)
        }
        .refreshable {
            await home.loadForClient(clientId: clientId)
            await model.reload(clientId: clientId)
        }
        .sheet(isPresented: Binding(
            get: { editingWorkout != nil },
            set: { if !$0 { editingWorkout = nil } }
        )) {
            if let plan = editingWorkout {
                CoachWorkoutPlanFormSheet(
                    clientId: clientId,
                    existing: plan,
                    onSave: { await model.reload(clientId: clientId) },
                    onDismiss: { editingWorkout = nil }
                )
            }
        }
        .sheet(isPresented: $showNewWorkout) {
            CoachWorkoutPlanFormSheet(
                clientId: clientId,
                existing: nil,
                onSave: { await model.reload(clientId: clientId) },
                onDismiss: { showNewWorkout = false }
            )
        }
        .sheet(isPresented: Binding(
            get: { editingMeal != nil },
            set: { if !$0 { editingMeal = nil } }
        )) {
            if let plan = editingMeal {
                CoachMealPlanFormSheet(
                    clientId: clientId,
                    existing: plan,
                    onSave: { await model.reload(clientId: clientId) },
                    onDismiss: { editingMeal = nil }
                )
            }
        }
        .sheet(isPresented: $showNewMeal) {
            CoachMealPlanFormSheet(
                clientId: clientId,
                existing: nil,
                onSave: { await model.reload(clientId: clientId) },
                onDismiss: { showNewMeal = false }
            )
        }
        .sheet(isPresented: Binding(
            get: { editingSchedule != nil },
            set: { if !$0 { editingSchedule = nil } }
        )) {
            if let ev = editingSchedule {
                CoachScheduleEventFormSheet(
                    coachUserId: auth.session?.user.id.uuidString ?? "",
                    clientId: clientId,
                    existing: ev,
                    onSave: { await model.reload(clientId: clientId) },
                    onDismiss: { editingSchedule = nil }
                )
            }
        }
        .sheet(isPresented: $showNewSchedule) {
            CoachScheduleEventFormSheet(
                coachUserId: auth.session?.user.id.uuidString ?? "",
                clientId: clientId,
                existing: nil,
                onSave: { await model.reload(clientId: clientId) },
                onDismiss: { showNewSchedule = false }
            )
        }
        .confirmationDialog("Delete this workout plan?", isPresented: Binding(
            get: { deleteWorkoutId != nil },
            set: { if !$0 { deleteWorkoutId = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = deleteWorkoutId {
                    Task {
                        try? await ClientDataService.coachDeleteWorkoutPlan(id: id)
                        deleteWorkoutId = nil
                        await model.reload(clientId: clientId)
                    }
                }
            }
            Button("Cancel", role: .cancel) { deleteWorkoutId = nil }
        }
        .confirmationDialog("Delete this meal plan?", isPresented: Binding(
            get: { deleteMealId != nil },
            set: { if !$0 { deleteMealId = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = deleteMealId {
                    Task {
                        try? await ClientDataService.coachDeleteMealPlan(id: id)
                        deleteMealId = nil
                        await model.reload(clientId: clientId)
                    }
                }
            }
            Button("Cancel", role: .cancel) { deleteMealId = nil }
        }
        .confirmationDialog("Delete this session?", isPresented: Binding(
            get: { deleteScheduleId != nil },
            set: { if !$0 { deleteScheduleId = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = deleteScheduleId {
                    Task {
                        try? await ClientDataService.coachDeleteScheduleEvent(id: id)
                        deleteScheduleId = nil
                        await model.reload(clientId: clientId)
                    }
                }
            }
            Button("Cancel", role: .cancel) { deleteScheduleId = nil }
        }
    }

    private var hubContent: some View {
        ZStack {
            Club360ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Write plans and sessions for \(memberName). Members see them when those features are enabled on their account.")
                        .font(.footnote)
                        .foregroundStyle(Club360Theme.cardSubtitle)
                        .fixedSize(horizontal: false, vertical: true)

                    Picker("Section", selection: $tab) {
                        ForEach(CoachPlansHubTab.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Club360Theme.tealDark)

                    if model.isLoading, model.workoutPlans.isEmpty, model.mealPlans.isEmpty, model.scheduleEvents.isEmpty {
                        ProgressView("Loading…")
                            .tint(Club360Theme.tealDark)
                            .frame(maxWidth: .infinity)
                    }

                    if let err = model.errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .club360Glass(cornerRadius: 22)
                    }

                    switch tab {
                    case .schedule:
                        scheduleSection
                    case .workouts:
                        workoutSection
                    case .meals:
                        mealSection
                    }
                }
                .padding()
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                showNewSchedule = true
            } label: {
                Label("Add session", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(Club360PrimaryGradientButtonStyle())
            .disabled(auth.session == nil)

            if model.scheduleEvents.isEmpty, !model.isLoading {
                Text("No sessions yet. Add training appointments or check-ins.")
                    .font(.subheadline)
                    .foregroundStyle(Club360Theme.cardSubtitle)
            }

            ForEach(model.scheduleEvents, id: \.id) { ev in
                coachEventRow(ev)
            }
        }
    }

    private func coachEventRow(_ ev: ScheduleEventDTO) -> some View {
        let rid = ev.rowId
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Club360DateFormats.displayDay(fromPostgresDay: ev.date)) · \(ev.time)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Club360Theme.cardTitle)
                    Text(ev.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Club360Theme.cardTitle)
                    if let n = ev.notes, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(n)
                            .font(.caption)
                            .foregroundStyle(Club360Theme.cardSubtitle)
                    }
                    if ev.isCompleted {
                        Text("Completed")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Club360Theme.tealDark)
                    }
                }
                Spacer()
            }
            if let rid, !rid.isEmpty {
                HStack(spacing: 12) {
                    Button("Edit") { editingSchedule = ev }
                        .font(.caption.weight(.semibold))
                        .tint(Club360Theme.tealDark)
                    Button("Delete", role: .destructive) {
                        deleteScheduleId = rid
                    }
                    .font(.caption.weight(.semibold))
                }
            } else {
                Text("Missing row id — cannot edit in app.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .club360Glass(cornerRadius: 24)
    }

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                showNewWorkout = true
            } label: {
                Label("Add workout plan", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(Club360PrimaryGradientButtonStyle())

            if model.workoutPlans.isEmpty, !model.isLoading {
                Text("No workout plans yet.")
                    .font(.subheadline)
                    .foregroundStyle(Club360Theme.cardSubtitle)
            }

            ForEach(model.workoutPlans, id: \.rowIdentity) { plan in
                coachWorkoutRow(plan)
            }
        }
    }

    private func coachWorkoutRow(_ plan: WorkoutPlanDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Week of \(Club360DateFormats.displayDay(fromPostgresDay: plan.weekStart)) — \(plan.title)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Club360Theme.cardTitle)
            Text(plan.planText)
                .font(.body)
                .foregroundStyle(Club360Theme.cardSubtitle)
            Text("Target sessions / week: \(plan.expectedSessions ?? 4)")
                .font(.caption.weight(.medium))
                .foregroundStyle(Club360Theme.cardSubtitle)
            if let pid = plan.id, !pid.isEmpty {
                HStack(spacing: 12) {
                    Button("Edit") { editingWorkout = plan }
                        .font(.caption.weight(.semibold))
                        .tint(Club360Theme.tealDark)
                    Button("Delete", role: .destructive) {
                        deleteWorkoutId = pid
                    }
                    .font(.caption.weight(.semibold))
                }
            } else {
                Text("Missing row id — cannot edit in app.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .club360Glass(cornerRadius: 24)
    }

    private var mealSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                showNewMeal = true
            } label: {
                Label("Add meal plan", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(Club360PrimaryGradientButtonStyle())

            if model.mealPlans.isEmpty, !model.isLoading {
                Text("No meal plans yet.")
                    .font(.subheadline)
                    .foregroundStyle(Club360Theme.cardSubtitle)
            }

            ForEach(model.mealPlans, id: \.rowIdentity) { plan in
                coachMealRow(plan)
            }
        }
    }

    private func coachMealRow(_ plan: MealPlanDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Week of \(Club360DateFormats.displayDay(fromPostgresDay: plan.weekStart)) — \(plan.title)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Club360Theme.cardTitle)
            Text(plan.planText)
                .font(.body)
                .foregroundStyle(Club360Theme.cardSubtitle)
            if let pid = plan.id, !pid.isEmpty {
                HStack(spacing: 12) {
                    Button("Edit") { editingMeal = plan }
                        .font(.caption.weight(.semibold))
                        .tint(Club360Theme.tealDark)
                    Button("Delete", role: .destructive) {
                        deleteMealId = pid
                    }
                    .font(.caption.weight(.semibold))
                }
            } else {
                Text("Missing row id — cannot edit in app.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .club360Glass(cornerRadius: 24)
    }
}

enum CoachPlansHubTab: String, CaseIterable {
    case schedule = "Schedule"
    case workouts = "Workouts"
    case meals = "Meals"
}

@Observable
@MainActor
private final class CoachPlansHubModel {
    var isLoading = false
    var errorMessage: String?
    var workoutPlans: [WorkoutPlanDTO] = []
    var mealPlans: [MealPlanDTO] = []
    var scheduleEvents: [ScheduleEventDTO] = []

    func reload(clientId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let w = ClientDataService.fetchWorkoutPlans(clientId: clientId)
            async let m = ClientDataService.fetchMealPlans(clientId: clientId)
            async let s = ClientDataService.fetchScheduleEvents(clientId: clientId)
            workoutPlans = try await w
            mealPlans = try await m
            let ev = try await s
            scheduleEvents = ev.sorted { a, b in
                let d0 = Club360DateFormats.postgresDay.date(from: a.date) ?? .distantPast
                let d1 = Club360DateFormats.postgresDay.date(from: b.date) ?? .distantPast
                if d0 != d1 { return d0 > d1 }
                return a.time > b.time
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Workout form

private struct CoachWorkoutPlanFormSheet: View {
    let clientId: String
    let existing: WorkoutPlanDTO?
    @State private var title: String
    @State private var weekStart: Date
    @State private var planText: String
    @State private var expectedSessions: Int
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onSave: () async -> Void
    let onDismiss: () -> Void

    init(clientId: String, existing: WorkoutPlanDTO?, onSave: @escaping () async -> Void, onDismiss: @escaping () -> Void) {
        self.clientId = clientId
        self.existing = existing
        self.onSave = onSave
        self.onDismiss = onDismiss
        if let e = existing {
            _title = State(initialValue: e.title)
            _weekStart = State(initialValue: Club360DateFormats.postgresDay.date(from: e.weekStart).map { Calendar.weekStartSunday(containing: $0) } ?? Calendar.weekStartSunday(containing: Date()))
            _planText = State(initialValue: e.planText)
            _expectedSessions = State(initialValue: max(1, min(14, e.expectedSessions ?? 4)))
        } else {
            _title = State(initialValue: "")
            _weekStart = State(initialValue: Calendar.weekStartSunday(containing: Date()))
            _planText = State(initialValue: "")
            _expectedSessions = State(initialValue: 4)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    DatePicker("Week (Sunday start)", selection: $weekStart, displayedComponents: [.date])
                    Stepper("Sessions / week: \(expectedSessions)", value: $expectedSessions, in: 1 ... 14)
                    TextEditor(text: $planText)
                        .frame(minHeight: 160)
                } footer: {
                    Text("Week is normalized to the Sunday-start week used across the app.")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New workout plan" : "Edit workout plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() async {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let id = existing?.id, !id.isEmpty {
                try await ClientDataService.coachUpdateWorkoutPlan(
                    id: id,
                    clientId: clientId,
                    title: t,
                    weekStart: weekStart,
                    planText: planText,
                    expectedSessions: expectedSessions
                )
            } else {
                try await ClientDataService.coachInsertWorkoutPlan(
                    clientId: clientId,
                    title: t,
                    weekStart: weekStart,
                    planText: planText,
                    expectedSessions: expectedSessions
                )
            }
            await onSave()
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Meal form

private struct CoachMealPlanFormSheet: View {
    let clientId: String
    let existing: MealPlanDTO?
    @State private var title: String
    @State private var weekStart: Date
    @State private var planText: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onSave: () async -> Void
    let onDismiss: () -> Void

    init(clientId: String, existing: MealPlanDTO?, onSave: @escaping () async -> Void, onDismiss: @escaping () -> Void) {
        self.clientId = clientId
        self.existing = existing
        self.onSave = onSave
        self.onDismiss = onDismiss
        if let e = existing {
            _title = State(initialValue: e.title)
            _weekStart = State(initialValue: Club360DateFormats.postgresDay.date(from: e.weekStart).map { Calendar.weekStartSunday(containing: $0) } ?? Calendar.weekStartSunday(containing: Date()))
            _planText = State(initialValue: e.planText)
        } else {
            _title = State(initialValue: "")
            _weekStart = State(initialValue: Calendar.weekStartSunday(containing: Date()))
            _planText = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    DatePicker("Week (Sunday start)", selection: $weekStart, displayedComponents: [.date])
                    TextEditor(text: $planText)
                        .frame(minHeight: 160)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New meal plan" : "Edit meal plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() async {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let id = existing?.id, !id.isEmpty {
                try await ClientDataService.coachUpdateMealPlan(
                    id: id,
                    clientId: clientId,
                    title: t,
                    weekStart: weekStart,
                    planText: planText
                )
            } else {
                try await ClientDataService.coachInsertMealPlan(
                    clientId: clientId,
                    title: t,
                    weekStart: weekStart,
                    planText: planText
                )
            }
            await onSave()
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Schedule form

private struct CoachScheduleEventFormSheet: View {
    let coachUserId: String
    let clientId: String
    let existing: ScheduleEventDTO?
    @State private var title: String
    @State private var day: Date
    @State private var timeText: String
    @State private var notes: String
    @State private var completed: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onSave: () async -> Void
    let onDismiss: () -> Void

    init(
        coachUserId: String,
        clientId: String,
        existing: ScheduleEventDTO?,
        onSave: @escaping () async -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.coachUserId = coachUserId
        self.clientId = clientId
        self.existing = existing
        self.onSave = onSave
        self.onDismiss = onDismiss
        if let e = existing {
            _title = State(initialValue: e.title)
            _day = State(initialValue: Club360DateFormats.postgresDay.date(from: e.date) ?? Date())
            _timeText = State(initialValue: e.time)
            _notes = State(initialValue: e.notes ?? "")
            _completed = State(initialValue: e.isCompleted)
        } else {
            _title = State(initialValue: "")
            _day = State(initialValue: Date())
            _timeText = State(initialValue: "")
            _notes = State(initialValue: "")
            _completed = State(initialValue: false)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $day, displayedComponents: [.date])
                    TextField("Time (e.g. 10:00 AM)", text: $timeText)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3 ... 6)
                    Toggle("Completed", isOn: $completed)
                } footer: {
                    Text("Sessions are stored on your coach calendar and linked to this client.")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New session" : "Edit session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || coachUserId.isEmpty || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() async {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !coachUserId.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let dayStart = Calendar.current.startOfDay(for: day)
        let time = timeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if let rid = existing?.rowId, !rid.isEmpty {
                try await ClientDataService.coachUpdateScheduleEvent(
                    id: rid,
                    clientId: clientId,
                    title: t,
                    date: dayStart,
                    time: time,
                    notes: n,
                    isCompleted: completed
                )
            } else {
                try await ClientDataService.coachInsertScheduleEvent(
                    coachUserId: coachUserId,
                    clientId: clientId,
                    title: t,
                    date: dayStart,
                    time: time,
                    notes: n,
                    isCompleted: completed
                )
            }
            await onSave()
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
