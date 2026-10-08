"""Repair Godot 4.4.1's non-Gradle Vulkan feature attribute serialization.

The exporter writes required/version as strings and omits version from the
resource map. Keep every other manifest node and APK entry unchanged; callers
must zipalign and sign the resulting APK again.
"""
import struct
import zipfile


def repair_manifest(data):
    data = bytearray(data)
    assert struct.unpack_from("<HH", data) == (3, 8), "Expected binary Android XML"
    chunks = []
    offset = 8
    strings = []
    resource_index = None
    while offset < len(data):
        kind, header, size = struct.unpack_from("<HHI", data, offset)
        assert size >= header >= 8 and offset + size <= len(data)
        chunk = bytearray(data[offset:offset + size])
        if kind == 1:
            count, _, flags, start = struct.unpack_from("<IIII", chunk, 8)
            def length(pos, wide=False):
                fmt, step, mask = ("<H", 2, 0x8000) if wide else ("<B", 1, 0x80)
                value = struct.unpack_from(fmt, chunk, pos)[0]
                pos += step
                if value & mask:
                    value = ((value & (mask - 1)) << (16 if wide else 8)) | struct.unpack_from(fmt, chunk, pos)[0]
                    pos += step
                return value, pos
            for i in range(count):
                pos = start + struct.unpack_from("<I", chunk, header + 4 * i)[0]
                if flags & 0x100:
                    _, pos = length(pos)
                    size_text, pos = length(pos)
                    strings.append(bytes(chunk[pos:pos + size_text]).decode("utf-8"))
                else:
                    size_text, pos = length(pos, True)
                    strings.append(bytes(chunk[pos:pos + size_text * 2]).decode("utf-16-le"))
        if kind == 0x180:
            resource_index = len(chunks)
        chunks.append(chunk)
        offset += size
    patched = 0
    version_indices = set()
    for chunk in chunks:
        if struct.unpack_from("<H", chunk)[0] != 0x102:
            continue
        if strings[struct.unpack_from("<I", chunk, 20)[0]] != "uses-feature":
            continue
        start, stride, count = struct.unpack_from("<HHH", chunk, 24)
        attrs = [16 + start + i * stride for i in range(count)]
        feature = None
        for pos in attrs:
            if strings[struct.unpack_from("<I", chunk, pos + 4)[0]] == "name":
                feature = strings[struct.unpack_from("<I", chunk, pos + 16)[0]]
        if feature not in ("android.hardware.vulkan.level", "android.hardware.vulkan.version"):
            continue
        for pos in attrs:
            name_index = struct.unpack_from("<I", chunk, pos + 4)[0]
            name = strings[name_index]
            if name == "version":
                version_indices.add(name_index)
            if name not in ("required", "version") or chunk[pos + 15] != 3:
                continue
            value = strings[struct.unpack_from("<I", chunk, pos + 16)[0]]
            if name == "required":
                assert value in ("true", "false")
                typed, value = 0x12, 0xffffffff if value == "true" else 0
            else:
                typed, value = 0x10, int(value, 0)
            struct.pack_into("<I", chunk, pos + 8, 0xffffffff)
            chunk[pos + 15] = typed
            struct.pack_into("<I", chunk, pos + 16, value)
            patched += 1
    if version_indices:
        assert resource_index is not None
        resources = chunks[resource_index]
        for index in version_indices:
            needed = 8 + 4 * (index + 1)
            resources.extend(b"\0" * max(0, needed - len(resources)))
            old = struct.unpack_from("<I", resources, 8 + 4 * index)[0]
            assert old in (0, 16844057)
            struct.pack_into("<I", resources, 8 + 4 * index, 16844057)
        struct.pack_into("<I", resources, 4, len(resources))
    output = data[:8] + b"".join(chunks)
    struct.pack_into("<I", output, 4, len(output))
    return bytes(output), patched


def repair_apk(source, destination):
    with zipfile.ZipFile(source) as src, zipfile.ZipFile(destination, "w") as dst:
        manifest, patched = repair_manifest(src.read("AndroidManifest.xml"))
        for entry in src.infolist():
            if entry.filename.startswith("META-INF/"):
                continue  # Signing metadata is replaced by apksigner.
            dst.writestr(entry, manifest if entry.filename == "AndroidManifest.xml" else src.read(entry))
    return patched
