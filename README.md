# StikFlash - Work in Progress (WIP)

Welcome to **StikFlash**, a work-in-progress Flash emulator that runs the **Ruffle Flash emulator** fully on your device! 🎉 With StikFlash, you can relive your favorite Flash games and apps in a secure, fast, and device-exclusive environment.

**Note**: StikFlash does not directly contain any Ruffle code. It utilizes Ruffle as an external library to power Flash emulation on iOS devices. 
Also, StikFlash needs an internet connection. Beta 3 should fix this by only requiring one after the first install.
A sideloading note, you cannot sign the ipa with an enterprise cert because the file importer will not work.
One more note, make sure low power mode is off. Having it on will greatly reduce performance.

## Features
- **Ruffle Flash Emulator Fully on Device**: StikFlash runs the Ruffle Flash emulator directly on your iOS device, using a built-in, secure web server. Flash files are pulled/downloaded from [Ruffle's official source](https://unpkg.com/@ruffle-rs/ruffle) to ensure private and seamless gameplay, with all operations happening entirely on your device. 🔒

## Compatibility
See the `Compatibility.md` file.

## Contributors
Credit to **nythepegasus** for adding xcconfigs.

## License
This project is licensed under the **AGPLv3**. You can find the full license text in the `LICENSE` file.

## How to Use
1. Download the latest release from the [Releases](https://github.com/0-Blu/StikEMU/releases) section.
2. Follow the setup instructions provided.
3. Load your Flash games, and enjoy the nostalgia!

## Feedback
Your feedback helps us improve StikFlash! Please [submit any issues](https://github.com/0-Blu/StikEMU/issues).

---

**Thank you for trying out StikFlash!** 🙌
