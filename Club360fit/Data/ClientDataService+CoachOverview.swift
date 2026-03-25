import Foundation
import Supabase

/// Aggregated reads for the coach dashboard (RLS limits to this coach’s clients / events).
extension ClientDataService {
    private static var overviewDb: SupabaseClient { Club360FitSupabase.shared }

    /// All workout plan rows visible to the signed-in coach (newest `week_start` first).
    static func fetchWorkoutPlansForCoach() async throws -> [WorkoutPlanDTO] {
        try await overviewDb
            .from("workout_plans")
            .select()
            .order("week_start", ascending: false)
            .execute()
            .value
    }

    /// All meal plan rows visible to the coach.
    static func fetchMealPlansForCoach() async throws -> [MealPlanDTO] {
        try await overviewDb
            .from("meal_plans")
            .select()
            .order("week_start", ascending: false)
            .execute()
            .value
    }

    /// Schedule events owned by the coach (`user_id`), any client.
    static func fetchScheduleEventsForCoach(coachUserId: String) async throws -> [ScheduleEventDTO] {
        try await overviewDb
            .from("schedule_events")
            .select()
            .eq("user_id", value: coachUserId)
            .order("date", ascending: true)
            .execute()
            .value
    }
}
