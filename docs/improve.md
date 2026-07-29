
---

# I'd also improve the app itself

Instead of cloning the old Android File Transfer app, build something closer to Finder.

## Sidebar

* 📱 Devices
* ⭐ Favorites
* 🕘 Recent
* 📂 Downloads
* 🔄 Transfers

## Main View

Finder-style table

```
Icon    Name            Size       Date Modified
📁      Download        --         Today
📁      DCIM            --         Yesterday
📄      file.pdf        12 MB      Jun 1
🖼️      IMG001.jpg      5 MB       Today
```

Double-click to open folders.

---

## Quick Preview

Spacebar should preview

* Images
* Videos
* PDFs
* Text files

---

## Drag & Drop

Exactly like Finder.

* Mac → Android
* Android → Finder
* Android → Desktop

---

## Context Menu

Right click:

```
Open

Download

Upload Here

Rename

Delete

Copy Path

Properties
```

---

## Transfer Manager

Bottom panel

```
Uploading...

█████████░░░░░

45%

2.3 MB/s

00:13 remaining
```

Support multiple simultaneous transfers.

---

## Device Information

Top of sidebar

```
📱 Pixel 9 Pro

Android 16

256 GB

182 GB free

USB 3.2
```

---

# My biggest recommendation

Don't use **MTP** directly.

Use **ADB** as the primary backend because it is generally more reliable and easier to script.

Design the app with a backend abstraction so you can add other transport methods later:

```
Transport Protocol

        │
 ┌──────┴────────┐
 │               │
ADB         Future MTP
 │               │
 └──────┬────────┘
        │
 File Manager
        │
    SwiftUI
```

This makes it easy to add features like Wi-Fi transfers (`adb tcpip`), wireless pairing, or even SMB in the future without rewriting the UI.
