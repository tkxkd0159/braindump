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
