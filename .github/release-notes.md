## Install

1. Download `BrainDump.dmg` below, open it, and drag **Brain Dump** to Applications.
2. **First launch** (the app is unsigned): double-click it once — macOS will block it.
   Open **System Settings → Privacy & Security**, scroll to the "Brain Dump was blocked"
   message, and click **Open Anyway**, then confirm.
3. If you instead see *"Brain Dump is damaged and can't be opened"*, run this once in
   Terminal, then reopen the app:

       xattr -dr com.apple.quarantine /Applications/BrainDump.app

This app is not notarized (no paid Apple Developer account), so macOS requires a
one-time manual approval. Source is public.

## Updates

From this version on, Brain Dump checks for updates once a day in the background
and can install them in one click (**Brain Dump ▸ Check for Updates…**, or
**Settings ▸ Software Update**). Updates are cryptographically signed.

If you're upgrading from an older build that predates auto-update, this one
release must be installed manually (download below); every release after it will
update in place.
