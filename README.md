# MPV Video Trimmer

A Lua script for [mpv media player](https://mpv.io/) to easily cut video clips from local files or streams, with subtitle support.

## Features
- Set start (`Ctrl+s`) and end (`Ctrl+e`) times for the clip.
- Cut and save the selected portion (`Ctrl+x`) as an MP4 file.
- Supports local videos and online streams.
- Preserves active subtitles (internal or external).
- Applies video filters if present.
- Saves clips to the Desktop (`~/Desktop/mpvstreamcut`) for streams or the source directory for local files.

## Requirements
- [mpv](https://mpv.io/) media player
- [FFmpeg](https://ffmpeg.org/) (for final encoding)

## Installation
1. Place the script in mpv's scripts directory:
   - Linux/macOS: `~/.config/mpv/scripts/`
   - Windows: `%APPDATA%\mpv\scripts\`
2. Ensure FFmpeg is installed and accessible in your system's PATH.

## Usage
1. Load a video or stream in mpv.
2. Press `Ctrl+s` to set the start time.
3. Press `Ctrl+e` to set the end time.
> **Note**: For frame-by-frame accuracy, pair with [mpv-frame-stepper](https://github.com/OHIOXOIHO/mpv-frame-stepper).
4. Press `Ctrl+x` to cut and save the clip.
5. The output file will be named `[filename]_[start]-[end].mp4`.

## Notes
- Ensure start time is before end time.
- Subtitles and video filters are automatically included if active.
- Temporary files are cleaned up after processing.
- For streams, output is saved to `~/Desktop/mpvstreamcut/`.

## License
MIT License
