[README.md](https://github.com/user-attachments/files/25447256/README.md)
# Bluee Mods — iOS Tweak

A mod menu dylib for Animal Company with item spawner, BMv1 radar button, and WiFi WebSocket support.

## How to build (no Mac needed)

1. **Create a free GitHub account** at github.com
2. **Create a new repository** — click the + icon → New repository → name it `blueemods` → set to Private → Create
3. **Upload all these files** keeping the same folder structure:
   ```
   .github/workflows/build.yml
   BlueeMods/Tweak.x
   BlueeMods/BlueeModsWindow.h
   BlueeMods/BlueeModsWindow.mm
   Makefile
   control
   ```
4. **Go to the Actions tab** in your repo — the build starts automatically
5. Wait ~5 minutes for it to finish
6. Click the completed run → scroll down to **Artifacts** → download **BlueeMods-dylib**
7. Inside the zip you'll find `BlueeMods.dylib` and a `.deb` package

## Installing on your iPhone

### Option A — TrollStore (no jailbreak needed on iOS 14–16.6.1)
1. Install TrollStore on your iPhone
2. Use an IPA patcher like **Sideloadly** or **Patchistador** to inject the dylib into Animal Company's IPA
3. Install the patched IPA via TrollStore

### Option B — Jailbroken device
1. Copy the `.deb` file to your device
2. Install via Filza or run `dpkg -i BlueeMods.deb` in a terminal

## Usage
- The **BMv1 radar button** appears in the bottom-right corner over the game
- Tap it to open the **Bluee Mods** menu
- Browse items by tab (Weapons / Gadgets / Natural / Food)
- Set quantity and tap any item card to spawn
- Tap **X** to close the menu — the BMv1 button reappears
- The button is draggable anywhere on screen

## Notes
- The dylib connects to `localhost:7777` for WebSocket by default
- Update the IP in `BlueeModsWindow.mm` → `autoConnect` method if needed
- Prefab names may need adjusting to match the exact Unity object names in-game
