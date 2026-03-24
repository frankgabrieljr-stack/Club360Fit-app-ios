# Club360Fit — iOS

SwiftUI + **Supabase Swift**, same backend as Android (`mjkrokpctcieahxtxvxq.supabase.co`).

## Git (separate from the Android repo)

The parent directory **Club360Fit App** is the **Android** project plus **Supabase** migrations. Its `.gitignore` **excludes** this `Club360Fit-iOS/` folder so the two apps are not mixed in one Git history.

**Recommended:** Run Git **inside** `Club360Fit-iOS/` (initialize a repo here if needed) and add `origin` pointing at your iOS remote. Commit and push Swift changes from that directory—**not** from the Android repo root.

The overview at the repo root is in **`../README.md`** (one level up from this folder).

## Project location

Open **`Club360Fit-iOS/Club360fit/Club360fit.xcodeproj`**.

Sources are in **`Club360fit/Club360fit/`** (Xcode file-system sync picks up new files automatically).

| File / area | Purpose |
|-------------|---------|
| `Club360fitApp.swift` | App entry, injects `Club360AuthSession` |
| `RootView.swift` | Loading → signed-in (client vs admin) → welcome + auth flow |
| `Club360AuthSession.swift` | Sign in / sign up / sign out, session + auth stream (matches Android `AuthViewModel`) |
| `WelcomeView.swift` | Logo, tagline, Create account / Sign in |
| `SignInView.swift` / `CreateAccountView.swift` | Email/password; create sends same metadata keys as Android |
| `ClientHomeView.swift` / `AdminHomeView.swift` | Client tab shell (Home / Workouts / Meals / Progress / Profile) + `ChangePasswordView` |
| `MyWorkoutsView.swift` | Client workouts: week progress, log session, plan list (Android `MyWorkoutsScreen`) |
| `MyMealsView.swift` / `MyMealPhotosView.swift` | Meal plans, meal photos card → upload to Storage `meal-photos` + `meal_photo_logs` (Android `MyMealsScreen` / `MyMealPhotosScreen`) |
| `CameraImagePicker.swift` | `UIImagePickerController` camera wrapper for **Take picture** on meal photos |
| `MyProgressView.swift` | Check-in history + **Log progress** sheet → `progress_check_ins` (Android `MyProgressScreen` / `ClientLogProgressDialog`) |
| `Data/Date+Week.swift`, `Data/WorkoutSessionLogDTO.swift` | ISO week Sunday + `workout_session_logs` insert/count |
| `Data/MealPhotoLogDTO.swift`, `Data/Club360Units.swift` | Meal photo rows + kg→lbs display (matches Android helpers) |
| `MyScheduleView.swift` | `schedule_events` — upcoming / past (Android `MyScheduleScreen`) |
| `MyDailyHabitsView.swift` | `daily_habit_logs` — water, steps, sleep (Android `MyDailyHabitsScreen`) |
| `MyPaymentsView.swift` | `client_payment_settings`, `payment_records`, `payment_confirmations` + QR (Android `MyPaymentsScreen`) |
| `MyNotificationsView.swift` | `client_notifications` + mark read (Android `MyNotificationsScreen`) |
| `TransformationGalleryView.swift` | Storage bucket **`transformations`** — carousel; admins can upload (Android `TransformationGalleryScreen`) |
| `UserProfileView.swift` | Avatar → **`avatars`** bucket + `user_metadata.avatar_url` (Android `UserProfileScreen`) |
| `Data/ClientFeatureDTOs.swift`, `Data/ClientDataService+ClientFeatures.swift`, `Data/Club360Formatting.swift` | DTOs + API for schedule, habits, payments, notifications, gallery |
| `QRCodeImageView.swift` | CoreImage QR for Venmo / Zelle strings |
| `PasswordFieldRow.swift` | Show/hide password (matches Android visibility toggle) |
| `ForgotPasswordView.swift` / `ChangePasswordView.swift` | Reset via email (`resetPasswordForEmail`) / change while signed in (`update(user:)`) |
| `SupabaseClient.swift` / `AppConfig.swift` | Supabase URL + anon key |
| `SupabaseUser+Role.swift` | `User.isAdminRole` from `user_metadata.role` |
| `Theme.swift` | Design tokens: mint / teal / peach / purple gradients + **`cardTitle` / `cardSubtitle`** for high-contrast text on tiles |
| `Club360UIComponents.swift` | **Glass cards** (white base + thin material + **visible border** + shadow), screen background, segmented progress bar, primary gradient button style |

### UI design (client shell)

The signed-in **client** experience uses a **glass / soft-gradient** look (mint–teal background, peach **next session** card, purple gradient **primary** buttons). **Tiles use ~28pt corner radius**, a **light opaque base** so they don’t blend into the gradient, a **1.25pt** light/dark **edge stroke**, and **near-black** (`cardTitle`) / **muted gray** (`cardSubtitle`) typography for readability. **Home** shows **“Welcome”** and the member’s **name** in **burgundy** next to the **`LogoBurgundy`** asset. The **Welcome** landing title also uses burgundy; auth flows share the same gradient **Form** background and gradient CTAs.

## Auth (aligned with Android)

- **Sign in:** `auth.signIn(email:password:)` then `auth.user()` to refresh metadata (same idea as Android `retrieveUserForCurrentSession`).
- **Sign up:** `auth.signUp` with metadata keys matching Android (`name`, `age`, …, `role`).
- **Role:** `user_metadata.role == "admin"` → **Admin home**; otherwise **Client home**.

If Supabase requires **email confirmation**, sign-up may return **no session** — the create-account screen shows “Check your email…”.

## Supabase package

**File → Packages → Resolve Package Versions** if needed (`https://github.com/supabase/supabase-swift`, 2.x).

## Configure the anon key

In **`AppConfig.swift`**, set `supabaseAnonKey` to the same **one-line** JWT as Android `local.properties` → `SUPABASE_ANON_KEY` (`eyJ…`). Do not break the string across lines.

## Build & run

⌘R in Xcode on a simulator or device.

## Client home (in progress)

- **`ClientHomeViewModel` + `ClientDataService`** load the same core data as Android `ClientHomeViewModel`: `clients` row, `workout_plans`, `meal_plans`, `progress_check_ins` (counts + current plan titles).
- **Workouts tab / Home → Workouts tile:** `MyWorkoutsView` — week logged vs expected (from current plan’s `expected_sessions`), **Log a workout today** → `workout_session_logs`, plan list with “Week of …” + `plan_text` (parity with Android `MyWorkoutsScreen`).
- **Meals tab / Home → Meals tile:** `MyMealsView` — meal plans + **Meal photos** → `MyMealPhotosView` (**Take picture** via `CameraImagePicker` or **Choose from library**, upload JPEG, list with public URLs; bucket **`meal-photos`** should be public like Android). **Privacy:** `NSCameraUsageDescription` is set in the Xcode target (generated Info.plist).
- **Progress tab / Home → Progress tile:** `MyProgressView` — check-ins (weight lbs, workout/meals flags, notes) + **Log progress** form.
- **Home:** **Next session** card (if `can_view_events`), **bell** → `MyNotificationsView` (unread badge), tiles for **Daily habits**, **Schedule**, **Payments**, **Gallery**, **Profile** (coach flags + `can_view_payments` respected).
- **Profile tab:** `UserProfileView` — avatar upload, role, change password, sign out.
- **Storage buckets** (create in Supabase if missing, public read where noted): `meal-photos`, `transformations`, `avatars`.

### Profile photo error: `new row violates row-level security policy`

That message usually means the **`avatars`** bucket exists but **`storage.objects`** has no policy allowing your user to **insert/update** under `{your-user-id}/avatar.jpg`.

**Fix:** In Supabase → **SQL Editor**, run **`supabase/migrations/013_avatars_storage.sql`**, then **`014_avatars_storage_uuid_case.sql`** (or merge the `lower(split_part …)` policy rules from `014` into your existing policies).

**Why `014`:** Swift’s `UUID.uuidString` is often **uppercase**; `auth.uid()::text` in Postgres is **lowercase**. A strict string match in RLS fails with “new row violates row-level security policy” even when policies exist. The app also lowercases the path on upload; `014` makes the policies case-insensitive.

## Next steps (porting)

- Flesh out **AdminHomeView** and coach flows to match `NavGraph.kt`.
- Add **password reset** UI after `club360fit://` opens the app (`ResetPasswordScreen` parity).

## Open in Cursor

Repo root, or **`Club360Fit-iOS`** / **`Club360Fit-iOS/Club360fit`**.
