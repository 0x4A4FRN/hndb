hndb is a statusbar for riverwm. It is mainly based on [levee](https://git.sr.ht/~andreafeletto/levee) and modified to cater my own use case.

## Build and install from source

##### Build Dependencies
- [zig](https://ziglang.org) 0.11.0
- [libpulse](https://www.freedesktop.org/wiki/Software/PulseAudio) 0.17.0
- [fcft](https://codeberg.org/dnkl/fcft) 3.1.7
- [wayland](https://wayland.freedesktop.org/) 1.22.0
- [pixman](https://pixman.org) 0.43.2
```
git clone https://git.sr.ht/~yorunosaurusrex/hndb
cd hndb 
zig build -Doptimize=ReleaseSafe --prefix ~/.local install
```
### Using your distro's package manager
##### Gentoo (needs [hands-overlay](https://git.sr.ht/~yorunosaurusrex/hands-overlay) repo enabled)
```
emerge --ask --verbose gui-apps/hndb
```
## Usage
Add this line to your ~/.config/river/init:
```
riverctl spawn "~/.local/bin/hndb"
```
