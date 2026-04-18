---
tags: [reference, rust]
---

# Rust FFmpeg Integration

## ffmpeg-next Crate

The `ffmpeg-next` crate (Rust bindings to libavcodec) is the primary way to use FFmpeg from Rust.

### Gotchas

- **FFmpeg 8 incompatible with ffmpeg-sys-next 7.x** (as of March 2026; ffmpeg-sys-next 7.1.3): FFmpeg 8.1 removed `avfft.h`, but `ffmpeg-sys-next` 7.1.3 still tries to generate bindings for it. Use FFmpeg 7 with ffmpeg-sys-next 7.x: `brew install ffmpeg@7` and `PKG_CONFIG_PATH="/opt/homebrew/opt/ffmpeg@7/lib/pkgconfig"`. Status unknown as of 2026-04-04 — verify if ffmpeg-sys-next now supports FFmpeg 8.

- **Crate name vs import name**: The crate is `ffmpeg-next` in Cargo.toml but imports as `ffmpeg_next`. Use `ffmpeg = { package = "ffmpeg-next", version = "7" }` for cleaner imports.

- **Encoder types are !Send**: `H264Encoder` wrapping ffmpeg contexts contains `SwsContext` raw pointers which are `!Send`. Cannot hold encoder across `.await` in tokio tasks. Solution: encode on a blocking thread (`std::thread::spawn`) and send pre-encoded frames through an `mpsc` channel.

- **Video encoder API types**: `encoder::video::Video` is the pre-open config type. `encoder::video::Encoder` is what `open()` / `open_with()` returns. They are different types — function signatures must use the correct one.

- **GLOBAL_HEADER flag**: Set `AV_CODEC_FLAG_GLOBAL_HEADER` on the codec context to store SPS/PPS in `extradata` rather than inline in each keyframe. Access extradata via unsafe raw pointer: `(*encoder.as_ptr()).extradata`.

- **VideoToolbox encoder name**: Use `"h264_videotoolbox"` as the codec name for hardware-accelerated H.264 on macOS. Set `"allow_sw" = "1"` to permit software fallback.

- **Extradata format varies by encoder**: `h264_videotoolbox` outputs AVCC format (version byte + length-prefixed param sets). `libx264` outputs Annex B (start codes). Must detect and handle both when parsing SPS/PPS.
