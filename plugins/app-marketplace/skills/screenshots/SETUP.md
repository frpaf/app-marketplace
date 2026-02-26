# Screenshots Skill — Setup Guide

This guide walks you through everything you need to install, step by step. No prior technical experience required.

---

## Automatic Setup (recommended)

Open Terminal (see Step 1 below if you don't know how) and run:

```
bash scripts/setup.sh
```

This will automatically check your computer and install everything that is missing. If it succeeds, skip ahead to **Step 6** (phone simulator setup) — the script handles Steps 2 through 5 for you.

If something fails to install automatically, follow the manual steps below.

---

## What you will install

| Tool | What it does | Time to install |
|------|-------------|-----------------|
| Node.js | Runs JavaScript tools | 2 minutes |
| Python 3 | Runs the image processing scripts | 2 minutes |
| Pillow | Adds image editing ability to Python | 1 minute |
| agent-device | Controls the phone simulator to take screenshots | 1 minute |
| Xcode or Android Studio | Provides the phone simulator/emulator | 10-30 minutes |

---

## Step 1: Open Terminal

### On Mac
1. Press **Command + Space** to open Spotlight
2. Type **Terminal**
3. Press **Enter**

A black or white window with a blinking cursor will appear. This is where you will type commands.

### On Windows
1. Press **Windows key**, type **PowerShell**
2. Click **Windows PowerShell**

### On Linux
1. Press **Ctrl + Alt + T**

---

## Step 2: Install Node.js

### On Mac

**Option A — Using the installer (easiest):**
1. Open your web browser and go to **https://nodejs.org/**
2. Click the big green button that says **"LTS"** (Long Term Support)
3. A `.pkg` file will download — double-click it
4. Click **Continue** through the installer, then **Install**
5. Enter your Mac password when asked

**Option B — Using Homebrew** (if you already have Homebrew):
```
brew install node
```

### On Windows
1. Go to **https://nodejs.org/**
2. Click the **LTS** download button
3. Run the `.msi` installer
4. Click **Next** through all steps — leave all defaults checked
5. Click **Install**, then **Finish**

### On Linux (Ubuntu/Debian)
```
sudo apt update
sudo apt install nodejs npm
```

### Verify it worked
Type this in Terminal and press Enter:
```
node --version
```
You should see something like `v20.11.0`. The exact number does not matter.

---

## Step 3: Install Python 3

### On Mac

**Option A — Using the installer (easiest):**
1. Go to **https://www.python.org/downloads/**
2. Click the yellow **"Download Python 3.x.x"** button
3. Open the downloaded `.pkg` file
4. Click through the installer and finish

**Option B — Using Homebrew:**
```
brew install python
```

### On Windows
1. Go to **https://www.python.org/downloads/**
2. Click **"Download Python 3.x.x"**
3. Run the installer
4. **IMPORTANT:** Check the box that says **"Add Python to PATH"** at the bottom of the first screen
5. Click **Install Now**

### On Linux (Ubuntu/Debian)
```
sudo apt update
sudo apt install python3 python3-pip
```

### Verify it worked
```
python3 --version
```
You should see something like `Python 3.12.0`.

---

## Step 4: Install Pillow (image processing library)

In Terminal, type:
```
pip3 install Pillow
```

If you see a "permission denied" error, try:
```
pip3 install --user Pillow
```

### Verify it worked
```
python3 -c "from PIL import Image; print('Pillow is ready')"
```
You should see: `Pillow is ready`

---

## Step 5: Install agent-device

In Terminal, type:
```
npm install -g agent-device
```

If you see a "permission denied" error on Mac/Linux, try:
```
sudo npm install -g agent-device
```
Enter your password when asked (you will not see the characters as you type — that is normal).

### Verify it worked
```
agent-device --help
```
You should see a list of available commands.

---

## Step 6: Set up a phone simulator

You need a virtual phone on your computer to run the app.

### For iOS apps (Mac only)

1. Open the **App Store** on your Mac
2. Search for **Xcode** and install it (it is free, but large — about 12 GB)
3. Open Xcode after installation
4. Go to **Xcode menu → Settings → Platforms**
5. Click the **+** button and install **iOS Simulator**
6. Close Xcode
7. Open **Simulator** app (search for it in Spotlight: Command + Space, type "Simulator")
8. A virtual iPhone will appear on screen

### For Android apps

1. Go to **https://developer.android.com/studio**
2. Download and install **Android Studio**
3. Open Android Studio
4. Go to **Tools → Device Manager**
5. Click **Create Virtual Device**
6. Pick a phone (e.g., "Pixel 7") and click **Next**
7. Download a system image (pick the latest) and click **Next**
8. Click **Finish**
9. Click the **Play** button next to your new device to start it

---

## Step 7: Install your app on the simulator

### For iOS
Your developer should provide you a `.app` file or you can build from source:
```
# If you have the source code (Flutter)
flutter run

# If you have a .app file, drag and drop it onto the Simulator window
```

### For Android
Your developer should provide you a `.apk` file:
```
# Install APK on running emulator
adb install path/to/your-app.apk
```

---

## Step 8: Run the screenshots skill

Make sure:
- The simulator/emulator is open and running
- Your app is installed on it

Then tell Claude:

> "Generate app store screenshots for com.example.myapp on ios for both stores"

Replace `com.example.myapp` with your actual app bundle ID (your developer can tell you this).

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `node: command not found` | Node.js is not installed. Go back to Step 2. |
| `python3: command not found` | Python is not installed. Go back to Step 3. |
| `No module named PIL` | Pillow is not installed. Go back to Step 4. |
| `agent-device: command not found` | agent-device is not installed. Go back to Step 5. |
| `permission denied` on any install | Add `sudo` before the command (Mac/Linux) or run as Administrator (Windows). |
| Simulator is not opening | Make sure Xcode (iOS) or Android Studio (Android) is fully installed. |
| App is not on the simulator | Ask your developer for the app file and install it (Step 7). |
| `npm: command not found` | Node.js is not installed properly. Reinstall from https://nodejs.org/ |
| Screenshots look wrong | Make sure the simulator is not rotated. Keep it in portrait mode. |

---

## Quick check — run all at once

Copy and paste this into Terminal to verify everything is installed:

```
echo "--- Checking Node.js ---" && node --version && echo "--- Checking Python ---" && python3 --version && echo "--- Checking Pillow ---" && python3 -c "from PIL import Image; print('Pillow OK')" && echo "--- Checking agent-device ---" && which agent-device && echo "" && echo "All good! You are ready to go."
```

If any line shows an error, go back to the matching step above.
