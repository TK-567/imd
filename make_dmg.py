#!/usr/bin/env python3
import os, sys, dmgbuild

OUT = "dist/imd-1.1.0.dmg"
BG = ".dmg_bg.png"
APP = "build/imd.app"

settings = {
    "filename": OUT,
    "volume_name": "imd",
    "format": "UDBZ",
    "size": None,
    "files": [(APP, "imd.app")],
    "symlinks": {"Applications": "/Applications"},
    "icon_locations": {
        # Iloc = 图标图像中心; 窗口 600x340, 垂直中心 170, 含标签微调 -> 165
        "imd.app": (150, 165),
        "Applications": (450, 165),
    },
    "background": BG,
    "window_rect": ((100, 100), (600, 340)),
    "icon_size": 96.0,
    "text_size": 14,
    "show_icon_preview": True,
}

os.makedirs("dist", exist_ok=True)
dmgbuild.build_dmg("imd", OUT, settings=settings)
print("built", OUT)
