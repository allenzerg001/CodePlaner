# codingplan.spec
import sys
from PyInstaller.utils.hooks import collect_all, collect_submodules

block_cipher = None

# Collect all submodules
datas = []
binaries = []
hiddenimports = []

for pkg in ['uvicorn', 'fastapi', 'starlette', 'pydantic', 'anyio', 'h11']:
    d, b, h = collect_all(pkg)
    datas += d
    binaries += b
    hiddenimports += h

hiddenimports += collect_submodules('src')
hiddenimports += ['src.main', 'src.config', 'src.models', 'src.crypto',
                  'src.core.router', 'src.core.converter', 'src.core.fallback', 'src.core.usage',
                  'src.routers.openai', 'src.routers.anthropic', 'src.routers.admin',
                  'src.providers.base', 'src.providers.bailian', 'src.providers.zhipu',
                  'src.providers.deepseek', 'src.providers.custom',
                  'cryptography', 'cryptography.hazmat.primitives.ciphers.aead']

a = Analysis(
    ['run_service.py'],
    pathex=['.'],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tkinter', 'test', 'unittest'],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='codingplan-service',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    onefile=True,
)
