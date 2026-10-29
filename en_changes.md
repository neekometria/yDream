GLEAM — METRIA PATCH v2

Changes:
- Volumetric clouds now ray-march the cloud slab from either direction, so the player can see the layer when above it and looking down.
- Nether cloud layer is anchored to a configurable world-space Y coordinate (default 400), with fixed-world procedural coverage and a settings control.
- Restored Gleam's full End, Nether and Northstar sky configuration from the supplied reference archive.
- End custom stars and nebula colors are active again; the molten planetary core is anchored at the sky zenith by default.
- The optional molten band around the End core is OFF by default; no black-hole disk or gravitational distortion is used.
- Venus defaults to a dense amber cloud-filtered sky, diffuse solar glow and almost invisible stars. Mars defaults to a thinner rusty dust haze with a darker zenith and subtle blue twilight. Moon and Mercury haze are set to zero by default.
- Restored the Gleam-style shader settings screens and descriptions for planet atmospheres and cloud controls.

Validation: archive structure and source-level checks only. The shader could not be launched in Minecraft in this environment, so in-game visual compilation still needs testing.

HOTFIX v2.1 — customStarsLayer compile error
- Restored the shared procedural customStarsLayer() implementation in shaders/lib/sky.glsl.
- The End, Nether, and Northstar sky code referenced this function, but the prior patch removed it while retaining its call sites.
- Kept Gleam's existing nightSkyLayer() implementation unchanged to avoid altering the Overworld star rendering.
- ZIP integrity and source-level checks passed. Runtime shader compilation still needs verification in Minecraft/Iris or the user's shader loader.

HOTFIX v2.2 — End core, Nether clouds, Northstar isolation
- End: the planetary core referenced END_CORE_DEEP, END_CORE_MID, END_CORE_HOT, END_CORE_VEIN, END_CORE_RIM and END_CORE_DIR without defining them. END_CORE is on by default, so the End sky failed to compile. The palettes are now defined from END_CORE_PALETTE (0 Molten orange = default, 1 Bright magma, 2 Deep mantle), and END_CORE_PALETTE is exposed on the End settings screen.
- End core default brightness lowered from 1.5 to 1.0. Core radiance is capped by END_CORE_RADIANCE_CAP (1.15) so the sphere stays clearly visible without pushing bloom or exposure into white.
- Nether clouds were gated by CLOUDS_OFF, which is only defined when vanilla clouds are off, so the Nether cloud layer never drew at default settings. The gate was removed; Nether clouds now depend only on NETHER_CLOUDS.
- The vanilla star overlay (star_data) now runs only in the Overworld. The Nether, End and all Northstar dimensions use only the custom star layer, which is still controlled by CUSTOM_DIMENSION_STARS.
- Northstar skybasic vertex wrappers define NORTHSTAR_DIM, so they no longer take the Overworld star overlay path.
- Mars: stars low on the horizon are dimmed by the dust haze (NORTHSTAR_MARS_STAR_DUST_FADE, default 0.45).
- Moon: moon vertex wrappers define NORTHSTAR_MOON so the lighting code can see it. Sunlight is neutral white (NORTHSTAR_MOON_SUN_LIGHT) instead of Earth-tinted daylight, and shadows get a small floor (NORTHSTAR_MOON_AMBIENT, default 0.10).
- Overworld (world0) files are unchanged.

Validation: source-level only. Shader compilation and in-game visuals were not tested in Minecraft or Iris in this environment. Verify with /execute in minecraft:the_end, minecraft:the_nether and northstar:mars, and check the Overworld after the change.

HOTFIX v2.3 — End rewrite
- The End sky was being overwritten. gbuffers_skytextured and gbuffers_skybasic ran the vanilla End sky quads and painted ZENITH_DAY_COLOR (near black) over the sky the prepare pass had just drawn. That is why the core did not show, palette changes did nothing and the End had no atmosphere. Both End paths now discard, so the prepared sky is the only sky.
- New lib/end_sky.glsl: one self-contained End atmosphere (gradient, horizon ember glow, molten core). No stars, clouds, nebula, aurora or shooting stars.
- End sky colours come from END_SKY_PALETTE (0 Ember void = default, 1 Violet abyss, 2 Ash and ember) and END_SKY_DEPTH. The vanilla-derived zenith/horizon colours now map to these, so fog and terrain agree with the sky.
- The core uses a sphere normal, convection noise and a horizon corona, and its radiance is capped by END_CORE_RADIANCE_CAP.
- Removed: END_CLOUDS (and lib/volumetric_clouds_end.glsl), END_NEBULA_STRENGTH, END_STAR_*, END_SHOOTING_STARS, END_AURORA*, END_CORE_CORRUPTION, END_CORE_STRIPE_WIDTH, END_CORE_DISK*, END_PALETTE and its palette block.

Validation: source-level only, not compiled or run in Minecraft or Iris. Check /execute in minecraft:the_end and look up at the zenith.

HOTFIX v2.4 — Nether parity with the Overworld, warmer End, purple core lines
- Nether clouds now use the Overworld volumetric cloud pass (cirrus + cloud layer, same planes and same vanilla cloud offset). The procedural Nether deck and its NETHER_CLOUDS / NETHER_CLOUD_Y / NETHER_CLOUD_DENSITY / NETHER_CLOUD_BRIGHTNESS options were removed; the Nether now follows the Overworld cloud settings.
- Nether stars use the Overworld night-sky star layer (clusters, hero stars, constellations, dust), with NETHER_STAR_BRIGHTNESS as a multiplier. CUSTOM_DIMENSION_STARS still toggles it.
- The deferred pass no longer overwrites the Nether sky with flat fog colour, which had erased the stars when clouds were off.
- The End sky is warmer and brighter: END_SKY_PALETTE 0 is now "Molten dusk" (warm amber overhead, bright orange at the horizon). End scene light is warm and controlled by END_SCENE_LIGHT.
- Core: purple lines wrap the molten core. Controlled by END_CORE_LINE_STRENGTH (0 turns them off), END_CORE_LINE_COUNT and END_CORE_LINE_PALETTE (Violet, Magenta, Deep indigo).
- Overworld (world0) files are unchanged.

Validation: source-level only, not compiled or run in Minecraft or Iris. Check /execute in minecraft:the_nether and look up, and confirm the Overworld cloud and star settings apply in the Nether.

HOTFIX v2.5 — Venus and Mars atmospheres, NASA-based
Venus (sources: NASA data as reported in NASA and university fact pages)
- About 96.5 % CO2, 3.5 % N2, surface pressure about 92 times Earth's.
- Sulfuric-acid cloud deck from about 45 to 70 km, opaque, reflects about 75 % of sunlight.
- At ground level: diffuse, dim, yellow-orange glow; the sun is a faint disk; no stars.
- Sun angular radius is 0.0064 rad (about 1.38 times Earth's, at 0.723 AU).
- New lib/planet_atmosphere.glsl: venusSkyColor(), venusSunTransmittance(). The sky is desaturated haze that gets denser toward the horizon, with a wide glow around the sun. The sun disk is attenuated by the cloud deck.
- Options: NORTHSTAR_VENUS_OPACITY (cloud optical thickness, default 1.0), NORTHSTAR_VENUS_LIGHT (warm diffuse ground light, default 0.8). Defaults for zenith, horizon and sun size were updated.

Mars (sources: NASA data as reported in NASA and university fact pages)
- About 95 % CO2, 3 % N2, 1.6 % Ar; mean surface pressure about 600 Pa (0.6 % of Earth's); scale height about 11 km.
- Dust is about 1.5 um; typical visible optical depth about 0.5 in clear seasons, higher in dust storms.
- Daytime sky is tawny. Near the sun it glows blue; sunsets are blue around the sun.
- New lib/planet_atmosphere.glsl: marsSkyColor(). Dust builds up toward the horizon, and a blue aureole forms around the sun, strongest at sunset.
- Options: NORTHSTAR_MARS_DUST_TAU (dust optical depth, default 1.0 to give a denser sky within the observed range), NORTHSTAR_MARS_LIGHT (daylight strength, default 1.0). Mars is still physically thin; density comes from dust, not pressure.

Lighting: Venus ground light is warm and diffuse; Mars light is slightly pale and neutral. NORTHSTAR_VENUS and NORTHSTAR_MARS are defined in the vertex wrappers, as NORTHSTAR_MOON already was.
Overworld, Moon and the other dimensions are unchanged.

Validation: source-level only. Not compiled or run in Minecraft or Iris. Check /execute in northstar:venus and northstar:mars at noon, sunset and night.

HOTFIX v2.6 — orbital dimensions (compatibility with Northstar 0.6.6, 1.21.1)
- Each planet's orbit now has its own shader folder: northstar_orbit_earth (also used by the Moon), northstar_orbit_mars, northstar_orbit_mercury, northstar_orbit_venus. Each folder defines NORTHSTAR_ORBIT_RADIUS from the mod's planet data (AU): Earth 1.0, Mars 1.52366231, Mercury 0.38709893, Venus 0.72333199.
- Sun size in orbit = 0.00465 rad / orbit radius, so it is larger over Mercury and smaller over Mars. The orbit sun also gets an inverse-square brightness factor, clamped to 0.35 to 3.0.
- Planets and the sun in orbit were black: the mod tints planet textures with its daylight value (gl_Color), which is zero at night, and the pack multiplied the texture by it. In orbit, skytextured now uses full tint and no sky-luma dimming. NORTHSTAR_ORBIT_PLANET_BRIGHTNESS controls the overall level.
- Limitation: the mod draws the sun sprite at a fixed size (ldc 15.0 in PlanetRenderer.render). The shader cannot resize that sprite, so the sprite looks the same in every