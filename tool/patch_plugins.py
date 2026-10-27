"""Fixes older Flutter plugins that predate AGP 8.

on_audio_query_android (and a few other 2022-era plugins) still ship a
build.gradle without a `namespace` and a manifest with a `package` attribute,
which AGP 8 rejects with "Namespace not specified". This runs in CI over the
pub cache and adds the namespace, drops the manifest package attribute and
raises a too-low minSdk. Idempotent: plugins that are already correct are
skipped.
"""
import os
import pathlib
import re


def _namespace_from_manifest(gradle_dir: pathlib.Path):
    manifest = gradle_dir / "src/main/AndroidManifest.xml"
    if manifest.exists():
        match = re.search(r'package="([^"]+)"', manifest.read_text())
        if match:
            return match.group(1), manifest
    for base in ("src/main/kotlin", "src/main/java"):
        root = gradle_dir / base
        if not root.exists():
            continue
        for source in sorted(root.rglob("*.kt")) + sorted(root.rglob("*.java")):
            rel = source.relative_to(root)
            if len(rel.parts) > 1:
                return ".".join(rel.parts[:-1]), manifest if manifest.exists() else None
    return None, None


def patch_gradle(build_file: pathlib.Path) -> bool:
    text = build_file.read_text()
    changed = False
    gradle_dir = build_file.parent

    if not re.search(r"^\s*namespace\s", text, re.M):
        namespace, manifest = _namespace_from_manifest(gradle_dir)
        if namespace:
            match = re.search(r"android\s*\{", text)
            if match:
                text = text[: match.end()] + '\n    namespace "' + namespace + '"\n' + text[match.end():]
                changed = True
            if manifest is not None:
                manifest_text = manifest.read_text()
                stripped = re.sub(r'\s*package="[^"]*"', "", manifest_text, count=1)
                if stripped != manifest_text:
                    manifest.write_text(stripped)

    def bump_min(match):
        return match.group(1) + str(max(int(match.group(2)), 21))

    def bump_compile(match):
        return match.group(1) + str(max(int(match.group(2)), 36))

    bumped = re.sub(r"(minSdkVersion\s+)(\d+)", bump_min, text)
    bumped = re.sub(r"(compileSdkVersion\s+)(\d+)", bump_compile, bumped)
    if bumped != text:
        text = bumped
        changed = True

    # AGP 8 fails with "Inconsistent JVM-target compatibility" when the plugin
    # leaves Java at 11 while Kotlin compiles at 17. Pin both to 17.
    if "compileOptions" not in text:
        block = (
            "\n    compileOptions {\n"
            '        sourceCompatibility JavaVersion.VERSION_17\n'
            '        targetCompatibility JavaVersion.VERSION_17\n'
            "    }\n"
            "    kotlinOptions {\n"
            '        jvmTarget = "17"\n'
            "    }\n"
        )
        anchor = re.search(r"android\s*\{", text)
        if anchor:
            text = text[: anchor.end()] + block + text[anchor.end():]
            changed = True

    if changed:
        build_file.write_text(text)
    return changed


def main() -> None:
    cache = pathlib.Path(os.path.expanduser("~/.pub-cache/hosted/pub.dev"))
    if not cache.exists():
        print("pub cache not found, nothing to patch")
        return
    patched = []
    for build_file in sorted(cache.glob("*/android/build.gradle")):
        try:
            if patch_gradle(build_file):
                patched.append(build_file.parent.parent.name)
        except Exception as error:  # noqa: BLE001 - never fail the build here
            print("skipped", build_file, error)
    print("patched plugins:", ", ".join(patched) if patched else "none")


if __name__ == "__main__":
    main()
