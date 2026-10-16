# Video Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent video upload flow to Videoteca on Android and web.

**Architecture:** `image_picker` selects one local video; a focused upload service sends it to Cloudinary with an unsigned preset. Firestore stores only metadata and provides the authenticated list. A publish coordinator sequences the two writes and exposes progress/errors to the dialog.

**Tech Stack:** Flutter/Dart, Firebase Auth, Cloud Firestore, Cloudinary Upload API, `image_picker`, `dio`.

**Spec:** [2026-10-15-video-upload-design.md](../specs/2026-10-15-video-upload-design.md)

## Global Constraints

- Android and web; preserve `com.faro.videos`, Firebase project `listasuper-75ab3`, and the celeste Videoteca identity.
- Cloudinary Free, one video per upload, at most 100 MB; title required, description optional.
- Author UID and display name come from Firebase Auth; date comes from Firestore server time. No manual author/date fields.
- No Firebase Storage, Cloudinary API secret, video playback, edit, delete, moderation, or complete public catalog.
- Firestore currently has its API disabled; enable and create its Standard `(default)` database before live persistence testing.
- Live Cloudinary upload requires a user-owned `cloud_name` and unsigned preset name. Neither is a secret; never commit a Cloudinary API secret.

## Review Focus

1. A file over 100 MB or with a non-video type must be rejected before network upload; Task 2 tests both.
2. Tapping Publish twice during upload must create one upload and one document; Task 3 tests this.
3. A failed Cloudinary upload must leave title, description, and file selection available for retry; Task 3 tests this.
4. A Firestore failure after Cloudinary success must report that publication failed and never claim success; Task 2 tests this and docs explain manual orphan cleanup.
5. Missing Firebase user or missing Cloudinary configuration must block publication with a useful message; Tasks 2 and 3 test these states.

---

### Task 1: Firestore video records and rules

**Files:** Create `lib/videos/video_record.dart`, `lib/videos/video_repository.dart`, `firestore.rules`; modify `firebase.json`, `pubspec.yaml`, `pubspec.lock`; test `test/videos/video_repository_test.dart`.

**Interfaces:** Produces `VideoRecord` with `id`, `title`, `description`, `videoUrl`, `cloudinaryPublicId`, `authorId`, `authorName`, `createdAt`; `VideoRepository.watchVideos(): Stream<List<VideoRecord>>`; `VideoRepository.createVideo({required String title, required String description, required String videoUrl, required String cloudinaryPublicId, required User author}): Future<void>`.

- [ ] **Step 1: Write failing tests.** Verify `createVideo` uses current user UID/name and `FieldValue.serverTimestamp()`; verify `watchVideos` maps persisted records ordered newest first and handles a pending/null timestamp. Use a Firestore test double or emulator, not a test that merely copies the serializer.
- [ ] **Step 2: Run `flutter test test/videos/video_repository_test.dart` and confirm failure.**
- [ ] **Step 3: Add `cloud_firestore` and implement the record/repository.** Store only Cloudinary URL/ID and text metadata in collection `videos`; use `displayName ?? 'Usuario'`. Keep title at 1–100 characters and description at 0–1000.
- [ ] **Step 4: Add `firestore.rules` and its entry in `firebase.json`.** Authenticated reads; authenticated creates only for their own `authorId`, allowed keys and field sizes, and server timestamp. Deny update/delete. Enable Firestore API, create Standard `(default)` database in an eligible region, deploy rules with Firebase CLI, then verify the deployed rules and database. If the account lacks permission, report the exact missing action.
- [ ] **Step 5: Run the test and `flutter analyze`, then commit Task 1 files.**

### Task 2: Selection, validation, and upload service

**Files:** Create `lib/videos/video_uploader.dart`, `lib/videos/video_publisher.dart`, `test/videos/video_publisher_test.dart`; modify `pubspec.yaml`, `pubspec.lock`.

**Interfaces:** Produces `VideoUploader.upload(XFile file, {required void Function(double) onProgress}): Future<UploadedVideo>` (`UploadedVideo` has `secureUrl`, `publicId`); `VideoPublisher.publish({required XFile file, required String title, required String description, required User? author, required void Function(double) onProgress}): Future<void>`. Consumes Task 1 `VideoRepository.createVideo`. Cloudinary `cloud_name` and preset come from `String.fromEnvironment` at build/run time.

- [ ] **Step 1: Write failing tests.** Cover missing file/title/user/config, type and 100 MB limits, upload errors, Firestore failure after upload, and a successful publish passing the authenticated author to Task 1.
- [ ] **Step 2: Run `flutter test test/videos/video_publisher_test.dart` and confirm failure.**
- [ ] **Step 3: Add `image_picker` and `dio`; implement selection validation and a streamed multipart upload to Cloudinary `/video/upload`.** Send `upload_preset` and file; parse `secure_url`/`public_id`; expose transfer progress. Handle Android and web `XFile` without `dart:io` in shared code. Never put Cloudinary API secret in source or runtime defines.
- [ ] **Step 4: Implement `VideoPublisher` to upload once and write Firestore metadata only after success.** Surface a specific publication error if Firestore fails; the orphaned Cloudinary file requires manual cleanup in this demo.
- [ ] **Step 5: Run the tests and `flutter analyze`, then commit Task 2 files.**

### Task 3: Upload dialog and persistent list

**Files:** Create `lib/videos/video_upload_dialog.dart`, `lib/videos/video_list.dart`, `test/videos/video_upload_dialog_test.dart`; modify `lib/main.dart`, `README.md`.

**Interfaces:** `VideoUploadDialog` consumes Task 2 `VideoPublisher` and invokes `ImagePicker.pickVideo(source: ImageSource.gallery)`; `VideoList` consumes Task 1 `VideoRepository.watchVideos()`.

- [ ] **Step 1: Write failing widget tests.** Verify the authenticated home shows a bottom-right upload FAB; dialog exposes file picker, title, description, publish action; duplicate taps during progress trigger one publish; failure preserves inputs; missing config gives an actionable message.
- [ ] **Step 2: Run `flutter test test/videos/video_upload_dialog_test.dart` and confirm failure.**
- [ ] **Step 3: Implement responsive dialog using existing Videoteca tokens.** Show selected filename/size, progress, field validation, loading and failure/success states. Fetch author from `FirebaseAuth.instance.currentUser`, with no author/date inputs.
- [ ] **Step 4: Replace the authenticated placeholder with a Firestore-backed list and add the FAB.** Show title, description, author and formatted server date; include loading, empty and error states. Keep playback out of scope.
- [ ] **Step 5: Document Cloudinary Free signup, unsigned preset restrictions, `--dart-define` values, 100 MB client limit, Firestore setup, and demo-only preset risk in `README.md`.**
- [ ] **Step 6: Run widget tests, all Flutter tests, `flutter analyze`, release web build, and debug APK build; visually inspect mobile and desktop dialog; commit Task 3 files.**

### Task 4: Live persistence smoke test

**Files:** Update `README.md` only if setup findings differ; no new product code unless a concrete integration defect appears.

**Interfaces:** Consumes all prior tasks and the user's Cloudinary `cloud_name`/unsigned preset.

- [ ] **Step 1: Verify Cloudinary preset accepts only intended video formats and disables overwrites; obtain `cloud_name` and preset from the user-owned account.**
- [ ] **Step 2: Run web with the two `--dart-define` values; sign in, upload a short test video, reload, and verify title, description, author and date persist.** Check Cloudinary asset and Firestore document. Use a disposable test account/video approved by the user; avoid creating content under their identity without approval.
- [ ] **Step 3: Check Android selection/upload on an available device or emulator.** If none is available, report that limit and retain the successful APK build as the Android verification.
- [ ] **Step 4: Run final tests and analysis; review changed files and report quota/security limits clearly.**
