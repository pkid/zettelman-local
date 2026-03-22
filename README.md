# Zettelman Local

A local-first SwiftUI iOS app for the German market that scans appointment notes, runs Apple Vision OCR on device, lets the user confirm the extracted fields, and stores everything locally with SwiftData.

## Features

- Import a note from the photo library or take a picture with the camera
- Run Apple Vision OCR with German and English text recognition
- Extract:
  - date and time
  - a short `what` summary (max 5 words)
  - location
- Show a confirmation sheet before saving
- Store appointments and the scanned image locally on device
- Browse all saved appointments and reopen the linked note image

## Tech

- SwiftUI
- SwiftData
- Vision OCR
- PHPickerViewController and UIImagePickerController
- Local image storage in Application Support

## Run

1. Open `ZettelmanLocal.xcodeproj` in Xcode.
2. Choose an iPhone simulator or device.
3. Build and run.

Camera capture needs a physical device. Photo library import works on simulator.
