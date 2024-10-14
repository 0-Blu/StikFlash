# StikFlash - Work in Progress (WIP)

Welcome to **StikFlash**, a work-in-progress Flash emulator that runs the **Ruffle Flash emulator** fully on your device! 🎉 With StikFlash, you can relive your favorite Flash games and apps in a secure, fast, and on-device environment.

## Notes: 
- StikFlash does not directly contain any Ruffle code. It utilizes Ruffle as an external library to power Flash emulation on iOS devices. 
- StikFlash needs an internet connection. Beta 3 should fix this by only requiring an internet connection after the first install.
- You cannot sign the ipa with an enterprise cert because the file importer will not work.
- Make sure low power mode is off. Having it on will greatly reduce performance.

## How It Works
- **Ruffle Flash Emulator Fully on Device**: StikFlash runs the Ruffle Flash emulator directly on your iOS device, using a built-in, secure web server. Flash files are pulled/downloaded from [Ruffle's official source](https://unpkg.com/@ruffle-rs/ruffle) to ensure private and seamless gameplay, with all operations happening entirely on your device. Only your device can connect to the web server, which uses a random port each time to increase security. 🔒

## Compatibility
See the `Compatibility.md` file.

## Discord
You can join my Discord server [here.](https://discord.gg/a6qxs97Gun)

## Contributors
Credit to **nythepegasus** for adding xcconfigs.

## License
This project is licensed under the **AGPLv3**. You can find the full license text in the `LICENSE` file.

## How to Install
### Method 1
1. Download the latest release from the [Releases](https://github.com/0-Blu/StikEMU/releases) section.
2. Use a Sideloading tool such as [SideStore.](https://sidestore.io)
3. Load your Flash games, and enjoy the nostalgia!
### Method 2
1. Join the [TestFlight](#) (Coming Soon).
2. Load your Flash games, and enjoy the nostalgia!

## Feedback
Your feedback helps us improve StikFlash! Please [submit any issues](https://github.com/0-Blu/StikEMU/issues) or join my [Discord server.](https://discord.gg/a6qxs97Gun)

---

**Thank you for trying out StikFlash!** 🙌
