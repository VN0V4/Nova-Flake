# Wallpapers

Put your own wallpapers in this folder (`.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`).
On rebuild, every image here is linked into `~/Pictures/Wallpapers`, so it shows
up in the shell's wallpaper picker and in the random wallpaper at login.

This is a flake, so Nix only sees files that git tracks. Images in this folder
are gitignored, so add yours with:

```sh
git add -f Wallpapers/your-image.jpg
```

Or skip the repo and drop images straight into `~/Pictures/Wallpapers`; the
picker reads that folder too.
