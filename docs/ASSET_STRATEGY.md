# Asset Strategy

## Visual target

Use polished stylized low-poly assets with bold silhouettes, readable trackside landmarks, and restrained materials. The game is not targeting photorealism or an exact visual reproduction of real circuits.

## Selection criteria

An asset may enter the project only when it:

- fits the rally-car and stylized environment direction;
- has a documented license compatible with private educational use;
- is available in glTF/GLB where possible, or can be safely converted;
- has acceptable mesh, texture, material, and animation cost for Android;
- fills a specific approved need rather than duplicating existing content.

## Preferred categories

- Cars: low-poly road/rally vehicles with recolorable materials.
- Trackside: barriers, chevrons, cones, banners without official branding, start/finish structures, and boost markers.
- Nature: grass, trees, rocks, shrubs, cliffs, and terrain details.
- UI/VFX/audio: touch icons, menus, dust, boost effects, interface cues, engine/skid/impact sounds, and short music loops.

## Environment asset brief

| Theme | Landmark direction |
| --- | --- |
| Spa forest | dense conifers, damp grass, forest banks, elevation framing |
| Alpine | rolling green slopes, fir trees, distant mountains |
| Parkland | mature trees, grass, low barriers, open sky |
| Open grassland | broad fields, sparse trackside structures, long visibility |
| Desert | sand, dry rock, scrub, warm sky |
| Forest | dirt banks, conifers, rocks, dense foliage |

## Android import rules

- Prefer GLB/glTF and shared materials.
- Use texture compression and practical 512/1024 texture sizes unless profiling proves more is safe.
- Remove unused animations, meshes, and materials before import.
- Instance repeated props and use distance/visibility limits.
- Avoid high-overdraw transparency and unique materials for scattered props.

## Provenance ledger

For every external asset, record source URL, creator, pack/version, license, attribution requirement, imported file path, modifications, destination theme, and review date. Store this ledger in `assets/ASSET_CREDITS.md` when the first asset is approved.

## Current status

Task 5.3 approved external asset packs are imported, optimized, and cataloged in `assets/ASSET_CREDITS.md` (`92` files, `5.64 MB` pre-compression):

- **Vehicles (CC0 1.0)**: Three Blender-normalized `-Z`-forward low-poly rally/touring variants (`rally_coupe.glb`, `rally_hatch.glb`, `touring_sedan.glb`) from Quaternius via Poly Pizza (`2,954–3,124` tris each) with standardized PBR slots (`BodyPaint`, `BodyAccent`) for player/AI coloring and ghost rendering.
- **Trackside & Boost Props (CC0 1.0)**: Start gantry (`12.88m` clear span), checkpoint arch, checkered flags, barriers, double guardrail, covered grandstand, paddock tent (`Kenney Racing Kit 2.0`), tire stack, traffic cone, wood fence (`Quaternius / Poly Pizza`), and a custom-extruded `-Z`-aligned `boost_pad.glb` (`76–1,776` tris, `Y=0` pivots, normalized dielectric PBR).
- **Six-Biome Nature Library (CC0 1.0)**: Conifers, broadleaf trees, bushes, grass/flowers, desert palm, small/saguaro cacti, boulders, alpine mountains, hills, clouds (`Kenney Nature Kit 2.1`, `Quaternius / Poly Pizza`, `KayKit Medieval Hexagon Pack 1.0`) scaled to world meters with non-metallic PBR and `256px` VRAM-compressed palette maps (KayKit grass palette cells shifted from chartreuse to cohesive meadow green in both extracted textures and embedded GLB buffers), instanced across all six biome presets via `MultiMeshInstance3D`.
- **Textures & VFX (CC0 1.0)**: Tileable surface color maps downscaled to `<=512px` (`Asphalt033`, `Concrete049`, `Grass005` from `ambientCG`; `Dirt 1` and `Sand1_0` by `LuminousDragonGames` via OpenGameArt) and `128px` particle sprites (`Kenney Particle Pack 1.1`), imported with `compress/mode=2` ETC2/ASTC VRAM compression and mipmaps.
- **UI Icons & Race Audio (ISC / CC0 1.0 / CC-BY 3.0)**: `26` crisp white `24x24` stroke SVG icons from `Lucide Icons` (ISC, `svg/scale=2.0` -> `48x48`); UI/boost/countdown/lap/menu audio (`Kenney Interface Sounds 1.0`, `Digital Audio`, `Music Jingles`) and race/engine/impact/skid audio (`OpenGameArt.org`, including `tire_skid.wav` under **CC-BY 3.0** aligned to a 44.1 kHz 16-bit mono 1.50 s zero-crossing loop and `impact_bump.ogg` peak-controlled below clipping at `-2.1 dBFS`).

Core vehicles, road/curb/ground materials, start gantry/flags, boost pad meshes, UI icons, mute controls, menu/UI audio, race audio (`RaceAudioController` with Master `AudioEffectLimiter` and foreground SFX ducking), all six procedural biome presets (`scripts/track/biome_presets.gd` using distance-culled zero-collider `MultiMeshInstance3D` batches shared across `MainController` and `TrackPreviewWidget`), 6-biome Track Builder UI, and mobile-budget `CPUParticles3D` car VFX (`scripts/racing/car_vfx_controller.gd`) are integrated.
