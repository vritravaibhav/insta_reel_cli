# Insta Video Downloader

A powerful CLI tool to download Instagram Reels and Videos directly from your terminal.

## Features

- 📥 Download Instagram Reels and Videos by URL.
- 🚀 Fast and efficient.
- 🛠️ Simple command-line interface.
- 🧩 robust fallback strategy for better success rates.

## Installation

You can install `insta_video_downloader` globally using Dart:

```bash
dart pub global activate insta_video_downloader
```

## Usage

Once installed, you can use the tool from your command line:

```bash
# Download a video by providing the URL
insta_video_downloader """<instagram_url>"""

# Example
insta_video_downloader """https://www.instagram.com/reel/C-xyz123/"""
```

## Running from Source

If you want to run the tool directly from the source code:

1. Clone the repository:
   ```bash
   git clone https://github.com/vritravaibhav/insta_reel_cli.git
   cd insta_video_downloader
   ```

2. Resolve dependencies:
   ```bash
   dart pub get
   ```

3. Run the tool:
   ```bash
   dart run bin/insta_video_downloader.dart <instagram_url>
   ```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
