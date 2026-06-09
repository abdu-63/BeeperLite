# BeeperLite

A lightweight, native iOS client for Beeper/Matrix, designed for iOS 15.1+ compatibility.

BeeperLite connects directly to the Beeper Matrix homeserver to fetch, view, and send messages in real-time, with local caching powered by Core Data.

## Features

- **SwiftUI Native UI**: Smooth, lightweight, and modern iOS interface.
- **Direct Beeper Integration**: Communicates directly with the `matrix.beeper.com` homeserver.
- **Secure Authentication**: Username & password login, with session tokens stored securely in the iOS Keychain.
- **Local Persistence (Core Data)**: Instant app loading with local caching of rooms, messages, and users.
- **Synchronization Engine**: Lightweight sync manager running background sync cycles.
- **Chat Details**: Real-time message streaming and support for sending new text messages.
- **E2EE Placeholders**: Safely flags encrypted messages to maintain maximum compatibility with iOS 15.1 (avoiding heavy, newer SDK dependencies).

## Tech Stack

- **Framework**: SwiftUI (Targeting iOS 15.1+)
- **Database**: Core Data
- **Secure Storage**: Keychain (Security Framework)
- **Networking**: URLSession async/await (REST API)

## Getting Started

### Prerequisites

- Xcode 13.0 or later
- iOS 15.1+ Device or Simulator

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/abdu-63/BeeperLite.git
   cd BeeperLite
   ```

2. Open `BeeperLite.xcodeproj` in Xcode.
3. Set your custom **Development Team** in the project's signing settings.
4. Run the project on your simulator or physical device.

## License

This project is open-source. Feel free to use and adapt it.
