"""Package the built resource without dependencies, tests or GitHub files."""

import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


def package_resource(resource_root, archive_path):
    required_paths = [
        'fxmanifest.lua', 'config.lua', 'data', 'modules',
        'web/index.html', 'web/style.css', 'web/app.js', 'web/images',
    ]
    for required_path in required_paths:
        if not (resource_root / required_path).exists():
            raise SystemExit(f'Missing release file: {required_path}')

    files = [resource_root / 'fxmanifest.lua', resource_root / 'config.lua']
    files.extend(resource_root.glob('*.md'))
    files.extend(resource_root.glob('LICENSE*'))
    for directory in ('data', 'modules', 'web'):
        for path in (resource_root / directory).rglob('*'):
            relative_path = path.relative_to(resource_root)
            if 'node_modules' in relative_path.parts or any(part.startswith('.') for part in relative_path.parts):
                continue
            if path.is_file():
                files.append(path)

    archive_path.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(archive_path, 'w', compression=ZIP_DEFLATED) as archive:
        for path in sorted(set(files)):
            archive.write(path, 'tss-inventory/' + path.relative_to(resource_root).as_posix())
    print(f'Created {archive_path} with {len(set(files))} files')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: package-release.py <output.zip>')
    package_resource(Path(__file__).resolve().parents[2], Path(sys.argv[1]).resolve())
