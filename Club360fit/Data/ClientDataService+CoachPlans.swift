import Foundation
import Supabase

/// Coach-only writes for `workout_plans`, `meal_plans`, and `schedule_events` (RLS: `coach_id` / `user_id`).
extension ClientDataService {
    private static var coachDb: SupabaseClient { Club360FitSupabase.shared }
    // MARK: - Workout plans

    static func coachInsertWorkoutPlan(
        clientId: String,
        title: String,
        weekStart: Date,
        planText: String,
        expectedSessions: Int
    ) async throws {
        let row = WorkoutPlanInsert(
            clientId: clientId,
            title: title,
            weekStart: Club360DateFormats.dayString(Calendar.weekStartSunday(containing: weekStart)),
            planText: planText,
            expectedSessions: max(1, min(14, expectedSessions))
        )
        let inserted: [WorkoutPlanDTO] = try await coachDb
            .from("workout_plans")
            .insert(row)
            .select()
            .execute()
            .value
        let pid = inserted.first?.id
        await ClientDataService.notifyMemberFromCoach(
            clientId: clientId,
            kind: "workout_plan",
            title: "New workout plan",
            body: title,
            refType: "workout_plan",
            refId: pid,
            dedupeKey: pid.map { "workout_plan_new:\($0)" }
        )
    }

    static func coachUpdateWorkoutPlan(
        id: String,
        clientId: String,
        title: String,
        weekStart: Date,
        planText: String,
        expectedSessions: Int
    ) async throws {
        let payload = WorkoutPlanUpdatePayload(
            title: title,
            weekStart: Club360DateFormats.dayString(Calendar.weekStartSunday(containing: weekStart)),
            planText: planText,
            expectedSessions: max(1, min(14, expectedSessions))
        )
        try await coachDb
            .from("workout_plans")
            .update(payload)
            .eq("id", value: id)
            .execute()
        await ClientDataService.notifyMemberFromCoach(
            clientId: clientId,
            kind: "workout_plan",
            title: "Workout plan updated",
            body: title,
            refType: "workout_plan",
            refId: id
        )
    }

    static func coachDeleteWorkoutPlan(id: String) async throws {
        try await coachDb
            .from("workout_plans")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Meal plans

    static func coachInsertMealPlan(
        clientId: String,
        title: String,
        weekStart: Date,
        planText: String
    ) async throws {
        let row = MealPlanInsert(
            clientId: clientId,
            title: title,
            weekStart: Club360DateFormats.dayString(Calendar.weekStartSunday(containing: weekStart)),
            planText: planText
        )
        let inserted: [MealPlanDTO] = try await coachDb
            .from("meal_plans")
            .insert(row)
            .select()
            .execute()
            .value
        let pid = inserted.first?.id
        await ClientDataService.notifyMemberFromCoach(
            clientId: clientId,
            kind: "meal_plan",
            title: "New meal plan",
            body: title,
            refType: "meal_plan",
            refId: pid,
            dedupeKey: pid.map { "meal_plan_new:\($0)" }
        )
    }

    static func coachUpdateMealPlan(
        id: String,
        clientId: String,
        title: String,
        weekStart: Date,
        planText: String
    ) async throws {
        let payload = MealPlanUpdatePayload(
            title: title,
            weekStart: Club360DateFormats.dayString(Calendar.weekStartSunday(containing: weekStart)),
            planText: planText
        )
        try await coachDb
            .from("meal_plans")
            .update(payload)
            .eq("id", value: id)
            .execute()
        await ClientDataService.notifyMemberFromCoach(
            clientId: clientId,
            kind: "meal_plan",
            title: "Meal plan updated",
            body: title,
            refType: "meal_plan",
            refId: id
        )
    }

    static func coachDeleteMealPlan(id: String) async throws {
        try await coachDb
            .from("meal_plans")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Schedule events (coach-owned `user_id`)

    static func coachInsertScheduleEvent(
        coachUserId: String,
        clientId: String,
        title: String,
        date: Date,
        time: String,
        notes: String,
        isCompleted: Bool
    ) async throws {
        let row = ScheduleEventInsert(
            userId: coachUserId,
            title: title,
            date: Club360DateFormats.dayString(date),
            time: time,
            notes: notes,
            clientId: clientId,
            isCompleted: isCompleted
        )
        let inserted: [ScheduleEventDTO] = try await coachDb
            .from("schedule_events")
            .insert(row)
            .select()
            .execute()
            .value
        let eid = inserted.first?.rowId
        await ClientDataService.notifyMemberFromCoach(
            clientId: clientId,
            kind: "schedule",
            title: isCompleted ? "Session logged" : "New session scheduled",
            body: "\(title) · \(Club360DateFormats.dayString(date))",
            refType: "schedule",
            refId: eid
        )
    }

    static func coachUpdateScheduleEvent(
        id: String,
        clientId: String,
        title: String,
        date: Date,
        time: String,
        notes: String,
        isCompleted: Bool
    ) async throws {
        let payload = ScheduleEventUpdatePayload(
            title: title,
            date: Club360DateFormats.dayString(date),
            time: time,
            notes: notes,
            isCompleted: isCompleted
        )
        try await coachDb
            .from("schedule_events")
            .update(payload)
            .eq("id", value: id)
            .execute()
        await ClientDataService.notifyMemberFromCoach(
            clientId: clientId,
            kind: "schedule",
            title: "Session updated",
            body: "\(title) · \(Club360DateFormats.dayString(date))",
            refType: "schedule",
            refId: id
        )
    }

    static func coachDeleteScheduleEvent(id: String) async throws {
        try await coachDb
            .from("schedule_events")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
