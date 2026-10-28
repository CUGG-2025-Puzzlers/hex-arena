"""Run four-player gameplay checks without loading four copies of full-size art."""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile
import time

from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("godot", help="Godot 4.6 executable")
    args = parser.parse_args()
    engine = str(Path(args.godot).resolve())
    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="hex-network-") as directory:
        fixture = Path(directory) / "project"
        shutil.copytree(source, fixture, ignore=shutil.ignore_patterns(".git", ".godot", "bin", "core", "core.*"))
        (fixture / "addons/epic-online-services-godot/bin").symlink_to(
            source / "addons/epic-online-services-godot/bin", target_is_directory=True)
        for texture in fixture.rglob("*.png"):
            Image.new("RGBA", (32, 32), (130, 180, 200, 255)).save(texture)
        with (Path(directory) / "import.log").open("w") as output:
            subprocess.run([engine, "--headless", "--editor", "--path", str(fixture), "--import", "--quit"],
                           stdout=output, stderr=subprocess.STDOUT, timeout=60, check=False)
        processes = []
        # Use a task-specific high port. Only this fixture's four processes share it.
        port = str(17000 + (int(time.time()) % 10000))
        try:
            for role in ("host", "client1", "client2", "client3"):
                log = Path(directory) / (role + ".log")
                output = log.open("w")
                process = subprocess.Popen([engine, "--headless", "--path", str(fixture),
                    "tests/playtest_network.tscn", "--", role, port], stdout=output, stderr=subprocess.STDOUT)
                processes.append((role, process, output, log))
                time.sleep(0.3)
            failed = False
            for role, process, output, log in processes:
                try:
                    process.wait(timeout=40)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                output.close()
                text = log.read_text()
                complete = "NETWORK_COMPLETE " + role in text
                errors = [line for line in text.splitlines() if "ERROR:" in line or "SCRIPT ERROR:" in line]
                print(role, "complete=" + str(complete), "engine_exit=" + str(process.returncode))
                for error in errors:
                    print(error)
                if not complete or errors:
                    failed = True
                    print(text[-6000:])
                elif process.returncode != 0:
                    known_shutdown = "double free or corruption" in text and process.returncode in (-6, 134)
                    print("  Known bundled EOS shutdown abort" if known_shutdown else "  Unexpected engine failure")
                    failed |= not known_shutdown
            return 1 if failed else 0
        finally:
            for _, process, output, _ in processes:
                if process.poll() is None:
                    process.kill()
                    process.wait()
                output.close()


if __name__ == "__main__":
    raise SystemExit(main())
