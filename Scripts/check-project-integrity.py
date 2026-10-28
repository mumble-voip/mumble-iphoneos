#!/usr/bin/env python3
"""Check local Xcode references, compiled app sources and packaged resources."""
from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'Mumble.xcodeproj/project.pbxproj'
project = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(PROJECT)]))
objects = project['objects']
reference_keys = {'fileRef', 'mainGroup', 'productReference', 'buildConfigurationList',
                  'baseConfigurationReference', 'target', 'targetProxy', 'remoteRef',
                  'containerPortal', 'ProjectRef', 'ProductGroup'}
reference_lists = {'children', 'files', 'buildPhases', 'dependencies', 'targets', 'buildConfigurations'}


def check_references(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if key in reference_keys:
                assert item in objects, f'Dangling project reference: {key}={item}'
            if key in reference_lists:
                assert all(ref in objects for ref in item), f'Dangling project list: {key}={item}'
            check_references(item)
    elif isinstance(value, list):
        for item in value:
            check_references(item)


check_references(project)
reachable = set()


def visit(value):
    if isinstance(value, str) and value in objects and value not in reachable:
        reachable.add(value)
        visit(objects[value])
    elif isinstance(value, dict):
        for item in value.values():
            visit(item)
    elif isinstance(value, list):
        for item in value:
            visit(item)


visit(project['rootObject'])
assert reachable == objects.keys(), f'Orphan project objects: {sorted(objects.keys() - reachable)}'
parents = {}
for identifier, obj in objects.items():
    for child in obj.get('children', []):
        assert child not in parents, f'File belongs to multiple project groups: {child}'
        parents[child] = identifier


def local_path(identifier):
    obj = objects[identifier]
    tree = obj.get('sourceTree', '<group>')
    if tree in ('SDKROOT', 'BUILT_PRODUCTS_DIR', 'DEVELOPER_DIR'):
        return None
    assert tree in ('<group>', 'SOURCE_ROOT'), f'Unexpected source tree: {tree}'
    parent = parents.get(identifier)
    base = ROOT if tree == 'SOURCE_ROOT' or not parent else local_path(parent)
    assert base is not None, f'Local file inside an external group: {identifier}'
    return (base / obj.get('path', '')).resolve()


files = {}
for identifier, obj in objects.items():
    if obj['isa'] == 'PBXFileReference':
        path = local_path(identifier)
        if path is not None:
            # The dependency build creates this ignored framework on a clean clone.
            generated = ROOT / 'Dependencies/Generated'
            assert path.is_relative_to(generated) or path.exists(), f'Missing file: {path}'
            files[identifier] = path
    elif obj['isa'] in ('PBXGroup', 'PBXVariantGroup'):
        assert obj.get('children'), f'Empty project group: {obj.get("name", identifier)}'

app = next(v for v in objects.values() if v['isa'] == 'PBXNativeTarget' and v['name'] == 'Mumble')
compiled = set()
packaged = set()
for phase in app['buildPhases']:
    kind = objects[phase]['isa']
    for build_file in objects[phase]['files']:
        ref = objects[build_file]['fileRef']
        if kind == 'PBXSourcesBuildPhase':
            compiled.add(files[ref])
        elif kind == 'PBXResourcesBuildPhase':
            if objects[ref]['isa'] == 'PBXVariantGroup':
                packaged.update(files[child] for child in objects[ref]['children'])
            else:
                packaged.add(files[ref])
source_files = {p.resolve() for p in (ROOT / 'Source').rglob('*') if p.suffix in ('.m', '.mm')}
assert compiled == source_files, f'Uncompiled or obsolete source: {sorted(compiled ^ source_files)}'
for path in (ROOT / 'Resources').rglob('*'):
    if path.is_file() and path.name not in ('README', 'Mumble-Translations-LICENSE.txt', '.DS_Store'):
        # The layered icon is compiled as one document, including its SVG/JSON.
        assert path.resolve() in packaged or any(parent in packaged for parent in path.resolve().parents), f'Unpackaged resource: {path}'
print(f'PASS project: {len(objects)} valid objects, {len(compiled)} app sources, {len(packaged)} packaged resources')
