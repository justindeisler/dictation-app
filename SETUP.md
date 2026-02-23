# DictationApp Setup Guide

A step-by-step guide to install DictationApp on your Mac. No programming experience needed.

---

## What You Need

| Requirement | Details |
|-------------|---------|
| **Mac** | macOS 14 (Sonoma) or later |
| **Groq API key** | Free at [console.groq.com/keys](https://console.groq.com/keys) |

---

## Step 1: Install DictationApp

### Option A: Download Pre-Built App (easiest)

No Xcode or developer tools needed.

1. Go to the [latest release](https://github.com/justindeisler/dictation-app/releases/latest)
2. Download **DictationApp-macOS.zip**
3. Open your Downloads folder and double-click the ZIP to unzip it
4. Drag **DictationApp.app** into your **Applications** folder

> **First launch — Gatekeeper warning:** Because the app isn't signed with an Apple Developer certificate, macOS will block it the first time. To open it: **right-click** (or Control-click) DictationApp.app, choose **Open**, then click **Open** in the dialog. You only need to do this once.

### Option B: Build from Source

This requires **Xcode** (free from the Mac App Store, ~7 GB download).

1. Install Xcode from the **Mac App Store**, then open it once to accept the license agreement
2. Download the source code:
   - **ZIP:** Go to the [GitHub page](https://github.com/justindeisler/dictation-app), click **Code > Download ZIP**, and unzip it
   - **Git:** `git clone https://github.com/justindeisler/dictation-app.git`
3. Open **Terminal** (Cmd+Space, type "Terminal", press Enter)
4. Navigate to the DictationApp folder. Type `cd ` (with a space), then **drag the folder from Finder into Terminal**. Press **Enter**. Or type it manually:
   ```bash
   cd ~/Downloads/DictationApp-main
   ```
5. Run the install script:
   ```bash
   ./install.sh
   ```
6. Wait for it to finish (1-2 minutes the first time). When you see **"Installation complete!"** the app is in your Applications folder.

> **If you see "permission denied":** Run `chmod +x install.sh` first, then try `./install.sh` again.

---

## Step 2: Get a Groq API Key

DictationApp uses Groq's speech-to-text service to transcribe your voice. You need a free API key.

1. Go to [console.groq.com/keys](https://console.groq.com/keys)
2. **Sign up** for a free account (or log in if you already have one)
3. Click **Create API Key**
4. Give it a name (e.g., "DictationApp") and click **Submit**
5. **Copy the key** — it starts with `gsk_`. You'll paste it in the next step.

> **Important:** You can only see the key once. Copy it now and keep it somewhere safe until you paste it into the app.

Groq's free tier is generous — more than enough for personal dictation use.

---

## Step 3: First Launch

1. Open **DictationApp**:
   - Open **Finder > Applications** and double-click DictationApp, or
   - Press **Cmd+Space**, type **DictationApp**, and press Enter

2. A small microphone icon will appear in your **menu bar** (the top-right area of your screen, near the clock)

3. Click the menu bar icon and select **Settings**

4. Paste your Groq API key into the **API Key** field

5. Close the Settings window — the key is saved automatically in your Mac's secure Keychain

---

## Step 4: Grant Permissions

macOS will ask for two permissions the first time you use DictationApp. **Both are required.**

### Microphone Access

- macOS will show a dialog: *"DictationApp would like to access the microphone"*
- Click **OK** to allow
- This lets the app record your voice for transcription

### Accessibility Access

- macOS will show a dialog asking for Accessibility access
- Click **Open System Settings** (or go to **System Settings > Privacy & Security > Accessibility**)
- Find **DictationApp** in the list and **turn on the toggle**
- This lets the app paste transcribed text into other apps using a simulated Cmd+V keystroke

### If You Accidentally Denied a Permission

1. Go to **System Settings > Privacy & Security**
2. Click **Microphone** or **Accessibility**
3. Find **DictationApp** in the list
4. Turn the toggle **on**
5. You may need to quit and reopen DictationApp for the change to take effect

---

## Step 5: Start Dictating!

1. Click into any text field (a document, email, search bar, etc.)
2. Press **Option+Space** to start recording
3. Speak naturally — you'll see an indicator in the menu bar showing that recording is active
4. Press **Option+Space** again to stop recording
5. Your transcribed text will be automatically pasted into the text field

> **Tip:** You can change the keyboard shortcut in Settings if Option+Space conflicts with another app.

---

## Troubleshooting

### "Xcode is not installed"

The install script requires full Xcode, not just the Command Line Tools.
- Install Xcode from the Mac App Store
- Open Xcode once to accept the license agreement
- Run `./install.sh` again

### "permission denied: ./install.sh"

The script needs permission to execute:
```bash
chmod +x install.sh
./install.sh
```

### "Build failed"

- Make sure Xcode is up to date (check in App Store > Updates)
- Try opening the project in Xcode directly: open `DictationApp/DictationApp.xcodeproj` and build with Cmd+R
- If you see signing errors, the ad-hoc signing should handle it — make sure you're using the install script

### App doesn't respond to the keyboard shortcut

- Make sure Accessibility permission is granted (System Settings > Privacy & Security > Accessibility)
- Try quitting and reopening the app
- Check that the shortcut isn't used by another app (change it in Settings)

### "Invalid API key" or transcription fails

- Double-check your API key at [console.groq.com/keys](https://console.groq.com/keys)
- Make sure you copied the full key (it starts with `gsk_`)
- Try creating a new key and pasting it again

### No audio / "Microphone access denied"

- Go to **System Settings > Privacy & Security > Microphone**
- Make sure DictationApp is listed and toggled **on**
- Quit and reopen the app

### Text doesn't paste into apps

- This means Accessibility access isn't granted
- Go to **System Settings > Privacy & Security > Accessibility**
- Find DictationApp and toggle it **on**
- Quit and reopen the app

---

## Updating DictationApp

**Pre-built download:** Go to the [releases page](https://github.com/justindeisler/dictation-app/releases/latest), download the latest ZIP, and replace the app in your Applications folder.

**Built from source:** Download the latest code (re-download the ZIP or `git pull`) and run `./install.sh` again — it will replace the old version.

---

## Uninstalling

1. Quit DictationApp (click the menu bar icon > Quit)
2. Delete `/Applications/DictationApp.app` (drag it to the Trash)
