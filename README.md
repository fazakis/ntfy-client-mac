# NtfyMacAlert

NtfyMacAlert is a lightweight native macOS desktop client for receiving alerts from [`ntfy.sh`](https://ntfy.sh) topics.

Milestone 1 focuses on reliable real-time receiving, clear in-app display, native macOS notifications, and a bundled characteristic alert sound.

## Features

- Native SwiftUI macOS app, no Electron.
- Default server: `https://ntfy.sh`.
- Supports self-hosted ntfy servers.
- Subscribe to one topic/channel at a time via the ntfy JSON stream endpoint.
- Optional Bearer token authentication.
- Real-time alert list with time received, topic, title, message, priority, and tags.
- Native macOS notifications using `UserNotifications`, with first-launch permission request and in-app permission status.
- Bundled `alert.aiff` sound played via `NSSound`.
- Sound enabled toggle, Test Sound button, Test Notification button, and Open Notification Settings button.
- Optional **Open at login** toggle using native macOS `SMAppService` login items.
- Automatic reconnect with exponential backoff: `1s`, `2s`, `5s`, `10s`, then `30s` max.
- Relaunch reconnect: if the app was left connected/reconnecting before quitting, it reconnects automatically on next launch.
- Last server URL, topic, sound setting, and reconnect-on-launch intent saved in `UserDefaults`.
- Access token stored in Keychain.

## Build

Open the project in Xcode 15 or newer:

```bash
open NtfyMacAlert.xcodeproj
```

Then build and run the `NtfyMacAlert` scheme.

You can also build from Terminal:

```bash
xcodebuild -project NtfyMacAlert.xcodeproj -scheme NtfyMacAlert -configuration Debug build
```

The deployment target is macOS 13.0.

## macOS notification permissions

NtfyMacAlert requests macOS notification permission on first launch. If the prompt appears, choose **Allow** so the app can show notification bubbles.

You can also manage this inside the app:

- **Notifications status** shows whether macOS currently allows notification delivery.
- **Request Notifications** asks macOS for permission when it has not been requested yet.
- **Test Notification** sends a local test bubble without needing an ntfy message.
- **Open Notification Settings** opens macOS notification settings if permission was denied or banners are disabled.
- **Refresh** reloads the current macOS permission state after you change System Settings.

If bubbles do not appear:

1. Open **System Settings → Notifications → NtfyMacAlert**.
2. Turn **Allow Notifications** on.
3. Enable **Banners** or **Alerts** as the alert style.
4. Enable **Show in Notification Center** if you want history.
5. Check that **Focus / Do Not Disturb** is not suppressing notifications.
6. Quit old copies of the app and launch the final installed copy. macOS tracks notification permissions by app identity and launch location, so a copied/debug build may appear as a separate notification entry.

If permission was denied, macOS usually will not show the permission prompt again. Use **Open Notification Settings** and enable it manually.

## Subscribe to a topic

1. Launch the app.
2. Leave the server URL as `https://ntfy.sh`, or enter your self-hosted ntfy server URL.
3. Enter a topic/channel name, for example:

   ```text
   my-test-topic-123
   ```

4. Optionally enter a Bearer token for protected topics.
5. Click **Connect**.

The status indicator shows whether the app is disconnected, connecting, connected, reconnecting, or in error.

## Reconnect on launch

NtfyMacAlert remembers the user's last connection intent:

- If you click **Connect** and quit while the app is connected, connecting, or reconnecting, it will automatically reconnect to the saved server/topic on the next launch.
- If you click **Disconnect**, automatic reconnect on the next launch is disabled.
- If the app cannot reconnect because of a permanent configuration/authentication error, such as an invalid URL or HTTP 401/403/404, it stops retrying and clears the reconnect-on-launch intent.

The Bearer token is still loaded from Keychain, so protected topics can reconnect without re-entering the token.

## Open at login

Turn on **Open at login** if you want NtfyMacAlert to start automatically when you log in to macOS.

Notes:

- The app uses native macOS `SMAppService` login-item registration.
- The app should be launched from its final installed location before enabling this option. Avoid enabling it from a temporary Xcode DerivedData/debug build.
- If macOS shows **Requires approval in System Settings**, open **System Settings → General → Login Items** and allow NtfyMacAlert.
- The login item launches the menu-bar app; it will also reconnect automatically if you previously left it connected.

## Send a test message

With the app connected to `my-test-topic-123`, publish a message:

```bash
curl -d "Hello from ntfy" https://ntfy.sh/my-test-topic-123
```

Expected result:

- the alert appears in the app,
- a native macOS notification appears if notification permission is allowed,
- the bundled alert sound plays if sound is enabled.

If notification bubbles do not appear, click **Test Notification** in the app. If that also does not show a bubble, use **Open Notification Settings** and make sure notifications are allowed with banner/list display enabled.

## License

MIT. See [LICENSE](LICENSE).

## Limitations

- Milestone 1 supports one active topic/channel at a time.
- Alert history is in-memory only and is cleared when the app quits.
- Notification delivery depends on macOS notification permissions and Focus settings.
- The app intentionally ignores ntfy `open` and `keepalive` stream events.

## Next milestones

- Menu bar mode and unread badge.
- Multiple topic subscriptions.
- Per-topic sound selection.
- Open/copy click URLs.
- Priority-based filtering.
- Persist notification history.
- Export alert history as JSON.
- Launch at login toggle.
