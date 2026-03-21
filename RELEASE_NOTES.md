# Princess Trackers Release Notes

## Version 1.0.4

This hotfix hardens mobile connectivity by automatically failing over to the live Railway host whenever the configured custom domain returns a dead Railway edge alias.

### Fixes

- Added API host failover between the configured host, the live Railway hostname, and the custom domain hosts.
- Realtime connections now rebuild against the active working API host after failover.
- Bumped the mobile app version for the connectivity fallback update.

## Version 1.0.3

This hotfix restores mobile connectivity by falling back to the live Railway hostname while the new custom domain is repaired.

### Fixes

- Switched the app's default API host back to the live Railway service hostname.
- Enabled realtime sync automatically for the live Railway service hostname.
- Bumped the mobile app version for the connectivity hotfix.

## Version 1.0.2

This update switches the mobile app to the new production domain and restores live connectivity against the current Tracker deployment.

### Fixes

- Updated the app's default API host to https://princesstrackers.com.
- Enabled realtime sync automatically for the live Princess Trackers domains.
- Bumped the mobile app version for rollout tracking.

## Version 1.0.0

Princess Trackers is now ready for broader release with a stronger focus on live coordination, offline reliability, and cleaner field workflows.

## Short Store Version

Live tracker updates, shared claim visibility, and better offline support are now in place. This release improves sync reliability, status handling, and overall day-to-day field use.

## Full Release Notes

### What's New

- Added live sync support so tracker updates appear more quickly across devices.
- Added shared claim handling so multiple users can stay aligned on the same work.
- Added offline action queuing so important updates can be saved locally and synced when connection returns.
- Improved app behavior to better match backend admin and tracker configuration.

### Improvements

- Improved reliability for status updates and claim actions.
- Improved handling of block and tracker state across screens.
- Refined mobile workflow details to reduce confusion during active use.
- Cleaned up several UI elements for a more focused field experience.

### Fixes

- Fixed sync-related issues that could leave devices out of date.
- Fixed cases where API responses could cause app-side failures.
- Fixed backend status-creation edge cases affecting mobile behavior.
- Fixed release build configuration issues for Android publishing.

## Play Console Draft

This update improves real-time coordination and field reliability. Trackers now sync more cleanly across devices, shared claims behave more consistently, and offline actions can be queued and synced later. We also fixed status-handling edge cases and improved overall app stability.

## Google Play Testing Upload Copy

Initial testing release for Princess Trackers. Includes live sync across devices, shared claim handling, offline action queueing, improved status reliability, and better alignment with backend tracker settings. This build focuses on field stability, cleaner workflows, and more consistent updates when connectivity changes.

## Internal Notes

- Android release bundle built successfully.
- Signing is configured locally for future Android releases.
- Keep the upload keystore and signing properties backed up securely before publishing updates.