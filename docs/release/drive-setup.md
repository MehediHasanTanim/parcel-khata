# Google Drive backup: one-time setup

The code (`lib/features/backup/application/drive_backup.dart`) uses Google Sign-In with the
`drive.appdata` scope only. It needs an OAuth client that cannot be created from the repository:

1. In Google Cloud Console create a project, enable the **Google Drive API**.
2. OAuth consent screen: add the scope `.../auth/drive.appdata` (non-sensitive, no verification wait).
3. Create an **Android** OAuth client with the package name and the SHA-1 of each signing key
   (debug, upload key, Play app-signing key).
4. Create a **Web** OAuth client and pass its id as `serverClientId` when initialising
   `GoogleSignIn.instance.initialize(...)` if Credential Manager requires it on your target devices.
5. Test on a real device: enable in Settings > Data > Google Drive backup, back up, then on a second
   device restore via "Restore from Drive" (preview -> merge/replace, the normal restore flow).

Background uploads run weekly on unmetered networks while charging (WorkManager). If silent
authentication fails in the background the failure is stored and the existing backup reminder keeps
firing, because a failed upload does not count as a backup.
