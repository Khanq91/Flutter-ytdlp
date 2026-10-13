"""Metadata regressions; no network or installed yt-dlp required."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import MagicMock, patch

BRIDGE_PATH = (Path(__file__).resolve().parents[2]
               / "android/app/src/main/python/ytdlp_bridge.py")
spec = importlib.util.spec_from_file_location("bridge_under_test", BRIDGE_PATH)
bridge = importlib.util.module_from_spec(spec)
stub = types.ModuleType("yt_dlp")
stub.YoutubeDL = MagicMock()
utils = types.ModuleType("yt_dlp.utils")
utils.DownloadCancelled = type("DownloadCancelled", (Exception,), {})
with patch.dict(sys.modules, {"yt_dlp": stub, "yt_dlp.utils": utils}):
    spec.loader.exec_module(bridge)


class MetadataTests(unittest.TestCase):
    def setUp(self):
        stub.YoutubeDL.reset_mock(return_value=True, side_effect=True)
        self.ydl = stub.YoutubeDL.return_value.__enter__.return_value

    def test_single_video_is_only_extracted_once(self):
        self.ydl.extract_info.side_effect = [
            {"id": "video", "title": "Video", "formats": [{"format_id": "mp4"}]},
            AssertionError("must not make a second metadata request"),
        ]
        result = json.loads(bridge.analyze("https://example.org/video"))
        self.assertNotIn("error", result)
        self.assertEqual(result["id"], "video")
        self.assertEqual(len(result["formats"]), 1)
        self.ydl.extract_info.assert_called_once()

    def test_playlist_preview_does_not_consume_entries(self):
        def entries():
            raise AssertionError("preview must not fetch every playlist page")
            yield  # A lazy generator which must never be advanced.
        self.ydl.extract_info.return_value = {
            "_type": "playlist", "title": "Music", "playlist_count": 115,
            "entries": entries(),
        }
        result = json.loads(bridge.analyze("https://youtube.com/playlist?list=test"))
        self.assertEqual(result["playlist_count"], 115)
        self.assertEqual(result["_type"], "playlist")

    def test_watch_url_with_list_is_requested_as_single_video(self):
        self.ydl.extract_info.return_value = {"title": "Video", "formats": []}
        bridge.analyze("https://youtube.com/watch?v=test&list=playlist")
        options = stub.YoutubeDL.call_args.args[0]
        self.assertTrue(options["noplaylist"])

    def test_extractor_error_is_returned_to_the_app(self):
        self.ydl.extract_info.side_effect = RuntimeError("Facebook: HTTP 403 detail")
        for operation in (bridge.analyze, bridge.get_playlist_entries):
            with self.subTest(operation=operation.__name__):
                result = json.loads(operation("https://example.org/video"))
                self.assertIn("HTTP 403 detail", result["error"])
                self.assertFalse(stub.YoutubeDL.call_args.args[0]["ignoreerrors"])

    def test_picker_loads_all_valid_entries(self):
        self.ydl.extract_info.return_value = {
            "title": "Music", "entries": [None, {}, {"id": "abc", "title": "Track"}],
        }
        result = json.loads(bridge.get_playlist_entries("https://youtube.com/playlist?list=test"))
        self.assertEqual(result["total"], 1)
        self.assertEqual(result["entries"][0]["id"], "abc")
        self.assertFalse(stub.YoutubeDL.call_args.args[0]["lazy_playlist"])

    def test_download_watch_url_does_not_expand_its_list(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "video.mp4"
            output.write_bytes(b"test")
            self.ydl.extract_info.return_value = {"title": "Video"}
            self.ydl.prepare_filename.return_value = str(output)
            with patch("builtins.print"):
                result = json.loads(bridge.download(
                    "task", "https://youtube.com/watch?v=test&list=playlist", "18", folder))
            self.assertTrue(result["success"])
            self.assertTrue(stub.YoutubeDL.call_args.args[0]["noplaylist"])


if __name__ == "__main__":
    unittest.main()
