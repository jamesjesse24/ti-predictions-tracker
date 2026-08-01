# Refresh timestamp behavior

The app now treats the visible `Last update` value as the time of the most recent successful network check. The remote repository feed's `generatedAt` value remains the tournament-data publication time and is appended to the synchronization status message.

This prevents the control-room timestamp from appearing frozen when the app is checking successfully but no new completed series has been published.
