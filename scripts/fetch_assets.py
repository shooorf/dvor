#!/usr/bin/env python3
"""
Автоматический загрузчик бесплатных CC0 3D-ассетов, 4K PBR-материалов и HDRI-неба
для уровня «Посёлок и Лес (Восточная Европа, Август)».

Источники (100% CC0 Public Domain, без регистрации и API-ключей):
  - Poly Haven (https://polyhaven.com) — 4K летнее HDRI-небо, 15 наборов 4K PBR-текстур
    (просёлочная дорога, трава, лесная тропа, сруб, крашеные доски, облупившаяся штукатурка, шифер, кирпич, кора)
    и 29 реальных 3D-фотосканов (кустарники, крапива, чистотел, трава, пни, поваленные стволы,
    уличные фонари, деревянные лавочки, лестницы, бочки, вёдра, топоры и оружие).
  - KayKit Adventurers (Kay Lousberg, CC0) — риггед 3D-персонажи с 76 боевыми анимациями.
  - Quaternius (CC0) — дополнительные модели оружия ближнего боя.

Использование:
  python scripts/fetch_assets.py --quality 4k   # Для ПК с RTX 4070 (по умолчанию)
  python scripts/fetch_assets.py --quality 1k   # Облегчённый профиль для быстрой проверки
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

USER_AGENT = "DvorSandboxAssetFetcher/2.0 (Godot4 Forward+)"
ROOT_DIR = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT_DIR / "assets" / "downloaded"

ASSET_PACK_VERSION = 2

# Реальное предзакатное летнее небо над просёлочной дорогой в Европе (Poly Haven CC0)
HDRI_ID = "evening_road_01_puresky"

PBR_TEXTURES = [
    # Ландшафт: луговая трава, просёлочная грунтовка, утоптанная тропинка, лесная подстилка
    "leafy_grass",
    "aerial_grass_rock",
    "brown_mud_leaves_01",
    "grass_path_2",
    "forest_leaves_02",
    # Сельская архитектура Восточной Европы: доски, сруб, штукатурка, кирпич, шифер/железо, бетон
    "brown_planks_03",
    "blue_painted_planks",
    "green_rough_planks",
    "blue_plaster_weathered",
    "worn_mossy_plasterwall",
    "brick_wall_001",
    "corrugated_iron",
    "gravel_concrete_02",
    "metal_plate",
    # Настоящая кора деревьев (сосна, ива/липа/яблоня)
    "knotted_pine_bark",
    "bark_willow_02",
]

POLYHAVEN_MODELS = [
    # Реальные 3D-фотосканы растительности, травы, крапивы, кустов и лесного бурелома
    "shrub_02",
    "shrub_03",
    "shrub_04",
    "fern_02",
    "grass_medium_01",
    "grass_medium_02",
    "weed_plant_02",
    "nettle_plant",
    "celandine_01",
    "tree_stump_01",
    "dead_tree_trunk",
    "dry_branches_medium_01",
    # Деревенский быт, дворы, освещение и интерактивные объекты песочницы
    "wooden_crate_01",
    "wine_barrel_01",
    "barrel_03",
    "boulder_01",
    "stone_fire_pit",
    "treasure_chest",
    "wooden_lantern_01",
    "street_lamp_01",
    "industrial_wall_lamp",
    "painted_wooden_bench",
    "wooden_picnic_table",
    "wooden_bucket_01",
    "wooden_ladder",
    "metal_jerrycan_green",
    # Фотосканированное холодное оружие и сельский инструмент
    "wooden_axe_02",
    "wooden_handle_saber",
    "wooden_hammer_01",
    "ornate_medieval_mace",
    "ornate_war_hammer",
]

KAYKIT_BASE = (
    "https://raw.githubusercontent.com/KayKit-Game-Assets/"
    "KayKit-Character-Pack-Adventures-1.0/main/"
    "addons/kaykit_character_pack_adventures/Characters/gltf"
)
CHARACTER_GLBS = {
    "Knight.glb": f"{KAYKIT_BASE}/Knight.glb",
    "Barbarian.glb": f"{KAYKIT_BASE}/Barbarian.glb",
    "Rogue_Hooded.glb": f"{KAYKIT_BASE}/Rogue_Hooded.glb",
}

QUATERNIUS_BASE = "https://raw.githubusercontent.com/trebeljahr/quaternius-showcase/main/public/glb"
WEAPON_GLBS = {
    "Sword.glb": f"{QUATERNIUS_BASE}/medieval_weapons_pack/Sword.glb",
    "Claymore.glb": f"{QUATERNIUS_BASE}/medieval_weapons_pack/Claymore.glb",
    "Club.glb": f"{QUATERNIUS_BASE}/single_knight_pack/Club.glb",
    "Axe.glb": f"{QUATERNIUS_BASE}/medieval_weapons_pack/Axe.glb",
}


def fetch_json(url: str, retries: int = 3) -> dict:
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except Exception as exc:
            if attempt == retries - 1:
                raise RuntimeError(f"Failed to query JSON {url}: {exc}") from exc
            time.sleep(1.2 * (attempt + 1))
    return {}


def download_file(url: str, dest: Path, force: bool = False, retries: int = 3) -> tuple[str, int, bool]:
    if dest.exists() and dest.stat().st_size > 0 and not force:
        return (str(dest.relative_to(ROOT_DIR)), dest.stat().st_size, True)

    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = dest.with_suffix(dest.suffix + ".part")

    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
            with open(tmp_path, "wb") as f:
                f.write(data)
            os.replace(tmp_path, dest)
            return (str(dest.relative_to(ROOT_DIR)), len(data), False)
        except Exception as exc:
            if tmp_path.exists():
                try:
                    tmp_path.unlink()
                except OSError:
                    pass
            if attempt == retries - 1:
                raise RuntimeError(f"Failed to download {url} -> {dest}: {exc}") from exc
            time.sleep(1.5 * (attempt + 1))
    return (str(dest), 0, False)


def build_download_plan(quality: str) -> tuple[list[tuple[str, Path]], set[Path]]:
    tasks: list[tuple[str, Path]] = []
    force_paths: set[Path] = set()

    print(f"[1/4] Fetching HDRI metadata ({HDRI_ID}, {quality})...")
    hdri_meta = fetch_json(f"https://api.polyhaven.com/files/{HDRI_ID}")
    hdri_res = quality if quality in hdri_meta["hdri"] else "1k"
    hdri_url = hdri_meta["hdri"][hdri_res]["hdr"]["url"]
    sky_dest = OUT_DIR / "hdri" / "sky.hdr"
    tasks.append((hdri_url, sky_dest))

    print(f"[2/4] Fetching PBR texture metadata ({len(PBR_TEXTURES)} sets, {quality})...")
    map_mapping = {
        "Diffuse": "diff.jpg",
        "nor_gl": "nor_gl.jpg",
        "arm": "arm.jpg",
    }
    for tex_id in PBR_TEXTURES:
        tmeta = fetch_json(f"https://api.polyhaven.com/files/{tex_id}")
        for ph_key, local_name in map_mapping.items():
            if ph_key not in tmeta:
                continue
            res_dict = tmeta[ph_key]
            chosen_res = quality if quality in res_dict else "1k"
            fmt_dict = res_dict[chosen_res]
            if "jpg" in fmt_dict:
                url = fmt_dict["jpg"]["url"]
                out_name = local_name
            elif "png" in fmt_dict:
                url = fmt_dict["png"]["url"]
                out_name = local_name.replace(".jpg", ".png")
            else:
                first_fmt = next(iter(fmt_dict.keys()))
                url = fmt_dict[first_fmt]["url"]
                out_name = local_name.replace(".jpg", f".{first_fmt}")
            tasks.append((url, OUT_DIR / "textures" / tex_id / out_name))

    print(f"[3/4] Fetching Poly Haven 3D photoscan metadata ({len(POLYHAVEN_MODELS)} models, {quality})...")
    for model_id in POLYHAVEN_MODELS:
        mmeta = fetch_json(f"https://api.polyhaven.com/files/{model_id}")
        gltf_res = quality if quality in mmeta["gltf"] else "1k"
        gltf_entry = mmeta["gltf"][gltf_res]["gltf"]
        model_dir = OUT_DIR / "models" / model_id
        tasks.append((gltf_entry["url"], model_dir / "model.gltf"))
        for rel_path, info in gltf_entry.get("include", {}).items():
            tasks.append((info["url"], model_dir / rel_path))
        if "Alpha" in mmeta:
            alpha_dict = mmeta["Alpha"]
            alpha_res = gltf_res if gltf_res in alpha_dict else ("1k" if "1k" in alpha_dict else next(iter(alpha_dict.keys())))
            alpha_fmts = alpha_dict[alpha_res]
            if "jpg" in alpha_fmts:
                tasks.append((alpha_fmts["jpg"]["url"], model_dir / "textures" / "alpha.jpg"))
            elif "png" in alpha_fmts:
                tasks.append((alpha_fmts["png"]["url"], model_dir / "textures" / "alpha.png"))

    print("[4/4] Adding rigged characters and melee weapons (CC0)...")
    for fname, url in CHARACTER_GLBS.items():
        tasks.append((url, OUT_DIR / "characters" / fname))
    for fname, url in WEAPON_GLBS.items():
        tasks.append((url, OUT_DIR / "weapons" / fname))

    return tasks, force_paths


def main() -> int:
    parser = argparse.ArgumentParser(description="Download free CC0 PBR & 3D assets for Village & Forest Sandbox.")
    parser.add_argument(
        "--quality",
        choices=["1k", "2k", "4k"],
        default="4k",
        help="Texture & model resolution profile (default: 4k for RTX 4070; use 1k for fast testing).",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-download and overwrite existing files.",
    )
    args = parser.parse_args()

    marker_file = OUT_DIR / "manifest.json"
    force = args.force
    prev_hdri = None
    if marker_file.exists() and not force:
        try:
            prev = json.loads(marker_file.read_text(encoding="utf-8"))
            prev_hdri = prev.get("hdri_id")
            if prev.get("quality") != args.quality:
                print(
                    f"Quality profile changed ({prev.get('quality')} -> {args.quality}), "
                    "refreshing assets..."
                )
                force = True
        except Exception:
            pass

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    # Force sky.hdr refresh if HDRI_ID changed from v1
    if prev_hdri != HDRI_ID and (OUT_DIR / "hdri" / "sky.hdr").exists():
        try:
            (OUT_DIR / "hdri" / "sky.hdr").unlink()
        except OSError:
            pass

    tasks, _ = build_download_plan(args.quality)
    total = len(tasks)
    print(f"Total files in download plan: {total} (profile: {args.quality})")

    downloaded_bytes = 0
    completed = 0
    errors: list[str] = []

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        future_map = {
            pool.submit(download_file, url, dest, force): (url, dest)
            for url, dest in tasks
        }
        for fut in concurrent.futures.as_completed(future_map):
            completed += 1
            try:
                rel_path, size, cached = fut.result()
                downloaded_bytes += size
                status = "cached" if cached else f"{size / 1024:.0f} KB"
                print(f"  [{completed:>3}/{total}] {rel_path} ({status})")
            except Exception as exc:
                errors.append(str(exc))
                print(f"  [ERROR] {exc}", file=sys.stderr)

    if errors:
        print(f"\nDownload finished with {len(errors)} error(s). Please re-run setup.bat.", file=sys.stderr)
        return 1

    manifest = {
        "pack_version": ASSET_PACK_VERSION,
        "hdri_id": HDRI_ID,
        "quality": args.quality,
        "files_count": total,
        "total_size_mb": round(downloaded_bytes / (1024 * 1024), 2),
        "licenses": {
            "Poly Haven (HDRI, PBR Textures, 3D Models)": "CC0 1.0 Public Domain (https://polyhaven.com/license)",
            "KayKit Character Pack Adventures": "CC0 1.0 Public Domain by Kay Lousberg (https://kaylousberg.com)",
            "Quaternius Medieval Weapons": "CC0 1.0 Public Domain by Quaternius (https://quaternius.com)",
        },
    }
    marker_file.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    print(
        f"\nDone! Verified/downloaded {total} files "
        f"({manifest['total_size_mb']} MB, profile: {args.quality})."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
