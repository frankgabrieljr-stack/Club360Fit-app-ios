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
        try await coachDb
            .from("workout_plans")
            .insert(row)
            .execute()
    }

    static func coachUpdateWorkoutPlan(
        id: String,
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
        try await coachDb
            .from("meal_plans")
            .insert(row)
            .execute()
    }

    static func coachUpdateMealPlan(
        id: String,
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
        try await coachDb
            .from("schedule_events")
            .insert(row)
            .execute()
    }

    static func coachUpdateScheduleEvent(
        id: String,
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
    }

    static func coachDeleteScheduleEvent(id: String) async throws {
        try await coachDb
            .from("schedule_events")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
