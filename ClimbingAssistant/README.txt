HOW TO OPEN CLIMBINGASSISTANT ON MACOS
=======================================

Requirements:
- Mac running macOS 13 (Ventura) or later
- Xcode 15 or later (free from the Mac App Store)
- An iPhone running iOS 16 or later (the Simulator cannot use the camera)

Steps:
1. Copy the ClimbingAssistant folder to your Mac (AirDrop, USB, cloud drive, etc.)

2. Double-click ClimbingAssistant.xcodeproj — Xcode will open the project.

3. In Xcode, go to:
   Navigator (left panel) > Click the top-level "ClimbingAssistant" project
   > Select the "ClimbingAssistant" target
   > "Signing & Capabilities" tab
   > Set "Team" to your Apple ID or developer account.

4. Plug in your iPhone via USB and select it from the device menu at the top
   of the Xcode window (next to the Run/Stop buttons).

5. Press Cmd+R (or click the Run button) to build and install the app.

6. The first time you run it, iOS will ask for camera permission — tap Allow.

7. Point the camera at a person. Yellow dots labeled LW, RW, LA, RA will
   appear tracking the left wrist, right wrist, left ankle, and right ankle.
   Cyan lines connect each wrist to its shoulder and each ankle to its hip
   when those joints are detected with sufficient confidence.

Troubleshooting:
- "Untrusted Developer" on iPhone: go to Settings > General > VPN & Device
  Management > tap your Apple ID > Trust.
- Build errors about signing: make sure you selected a valid Team in step 3.
- No dots appearing: ensure the full body is visible and well-lit. The Vision
  framework requires a confidence of 0.5 or higher to display a joint.
