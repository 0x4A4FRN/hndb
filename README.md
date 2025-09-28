hndb is a statusbar for riverwm. It is mainly based on [levee](https://git.sr.ht/~andreafeletto/levee) and modified to cater my own use case.

## Build and install from source

##### Build Dependencies

- [zig](https://ziglang.org) 0.16.0-dev.368+2a97e0af6
- [libpulse](https://www.freedesktop.org/wiki/Software/PulseAudio) 0.17.0
- [fcft](https://codeberg.org/dnkl/fcft) 3.3.2
- [wayland](https://wayland.freedesktop.org/) 1.24.0
- [pixman](https://pixman.org) 0.46.4

```
git clone https://git.sr.ht/~_0x4a4frn/hndb
cd hndb
zig build -Doptimize=ReleaseSafe --prefix ~/.local install
```

## Usage

Add this line to your ~/.config/river/init:

```
riverctl spawn "~/.local/bin/hndb"
```
