# Gleam Shaders

Gleam is a shader pack for people who want Minecraft to look beautiful without needing a monster GPU. It's built on the fast rendering core of [MakeUp UltraFast](https://github.com/javiergcim/MakeUpUltraFast) by Javier Garduño, but the sky, clouds, water, lighting and night are all its own. Almost everything can be changed in the settings, and it runs on Iris, OptiFine and Apple Silicon Macs (nothing above OpenGL 4.1 is used).

Requires Iris 1.5.1 or newer, or OptiFine.

## Pick your look

There are seven styles, and you can mix them with any color scheme and performance profile.

- **Fantasy** is the default: warm golden light, deep blue skies, violet and magenta twilights, a soft round sun, volumetric clouds and a bit of magic at night.
- **Vanilla** keeps Minecraft's own sun, moon, stars and blocky clouds, then cleans up the lighting around them.
- **Realistic** aims for a photograph: a physically shaped daytime sky, a small sun and moon at believable size, neutral color, soft shadows and a natural tone curve, with no aurora or other fantasy touches.
- **Cinematic** is built for screenshots: a cool teal-and-orange grade, a warm halation glow around bright highlights, lens flare, film grain, a vignette, soft shadows and strong godrays.
- **Anime** is a flat, bold cel-shaded look: punchy saturated colors, hard-edged shadows, and a dark cartoon outline drawn around every silhouette.
- **Color schemes** now include Tropical Lagoon, Violet Twilight, Misty Forest, Desert Gold and Midnight Blue, and the aurora has four more palettes.
- **Grading & Filters** (Color settings) adds Sepia, Noir, Teal & Orange, Pastel and Sunset Glow filters plus shadow lift, highlight boost, gamma and matte fade.
- **Aurora** now has its own settings screen: speed, rays, height, base height, patchiness, ripple, direction, color spread and a fully custom color palette.
- **Shooting stars** are customizable: amount, frequency, brightness, trail length, speed and color (presets, aurora colors, rainbow or your own).
- **Performance** has a Performance mode (Quality, Balanced, Fast, Max FPS) plus cloud, godray, reflection and ambient occlusion detail sliders. Balanced is the default.
- **Godrays** are stronger and more cinematic, with warmth, spread and focus controls.
- Every setting now has a color that matches its menu group, and the menus are reorganized.
- **The End** has an End palette, nebula, star, horizon glow, shooting star and void aurora controls. **The Nether** has ember colors and a heat haze glow. Both are under Dimensions.
- Integrated PBR, global illumination and colored lighting all live under Experimental.
- **Emissive** glowing blocks have richer color, a white-hot core and a night boost, and there is a new wide bloom layer. Fantasy has richer sunsets, haze and bloom.
- The default performance mode is now Fast.
- **Night skies** have bright glowing stars with soft sparkle, glowing constellation lines, a deeper indigo sky tint, richer moonlight colors, and moon size and color options.
- **Profiles**: Performance, Fast, Quality, Cinematic, Fantasy, Natural and Anime quick presets.
- **Natural** is a clean, true-to-life look: a light blue sky, light blue water, soft white clouds, gentle bloom and neutral warm light, with no aurora by default.
- **Custom** lets you set every sky and light color yourself.

Five color schemes change the whole palette (sky, light, sunsets, night, aurora): Golden Hour, Arctic, Neon Dusk, Crimson Ember and Pastel Dream.

Six performance profiles: Potato, Swift, Standard, Polished, Ultra and Showcase — a screenshot-only preset that pushes every effect to its heaviest setting and is not meant for normal play.

## Sky and night

- Sunrises and sunsets follow the real height of the sun, with a proper golden-hour blend instead of muddy in-between colors.
- Round sun with a soft glow. Round moon with all eight phases, maria and earthshine.
- Stars, shooting stars, and auroras that sweep across the whole sky in layered arcs, with a corona overhead.
- Aurora curtains that light up the terrain below them. You choose how much of the sky they cover.
- An "Enchanted" night look with cool moonlight, a moon halo and faint nebula wisps.
- Lens flare with a string of rotated hexagonal ghosts, a spectral halo and a color-graded anamorphic streak, tuned per style from a subtle touch in Realistic to a strong cinematic flare.

## Clouds

- Two volumetric cloud modes, soft and detailed, that light themselves from the sun, shade their own undersides and glow along their edges at sunset, with Realistic toned down to an overcast-photograph look instead of a dramatic glow.
- A thin cirrus layer high above.
- Vanilla block clouds with rounded, puffy silhouettes instead of hard cubes, softly faded edges with a faint sunlit rim for a storybook look, plus proper face and height shading and warm sun-facing sides. Choose the full 3D blocks or a fast flat layer if you want the FPS, and dial the roundness and edge softness anywhere from soft cotton clumps back to classic sharp cubes.
- Clouds show up in water reflections.

## Light and shadows

- Shadow filtering follows your style by default: world-locked pixel shadows that don't crawl when you move for Fantasy and Vanilla, soft shadows for Realistic and Cinematic. You can also pick simple, soft or pixelated yourself.
- Colored shadows through stained glass.
- Godrays with a golden-hour boost, a cheap screen-space mode, and optional colored shafts, including shimmering light shafts underwater tinted to match the water color.
- Ambient occlusion, sky-aware ambient light, and light that glows through leaves and grass when the sun is behind them.
- Warm block light, dynamic hand light, and glowing ore veins.
- LabPBR support for normals, specular, metals, ambient occlusion, emission, and parallax occlusion mapping for real surface depth on bricks, cobble and more.
- Ground fog that thickens at dawn, dusk and in the rain.
- Aerial perspective: distant scenery eases toward the sky color for a real sense of depth.
- Rain wetness that darkens and lightly sheens exposed surfaces, then dries out after the storm passes.

## Water

- Soft rolling waves, sun glints and glitter, reflections of the sky (three quality levels, up to raymarched), and streaky shoreline foam. Realistic uses a more natural, less saturated water color and a stronger, true-to-life Fresnel curve.
- Shore foam, shallow-to-deep color, and refraction.
- One water color drives both the surface and the underwater fog, so they always match. Water color presets included.
- Underwater fog that absorbs red first and gets darker with depth, volumetric light shafts that now reach below the surface, plus a clean view of the sky from below.

## Other dimensions

- The Nether takes its fog, sky and ambient tint from the biome you're in, with low glowing mist, drifting embers, and a warm fill light from below.
- The End has a nebula band across the sky and a starry backdrop.

## Color and effects

- Three tone curves (Gleam, Natural and Filmic), plus exposure, contrast, saturation, warmth, tint and vibrance.
- Bloom, vignette, film grain, cinematic letterbox bars that slide in while you sneak, sharpening, chromatic aberration, depth of field and motion blur.
- Anti-aliasing: temporal (the default), TAA or FXAA.
- Color-blind modes.
- Optional enchantment glint recoloring (custom color, animated rainbow, or an accent that matches your color scheme) — defaults to matching your color scheme.
- Optional cartoon ink outlines around every silhouette, with adjustable strength, thickness and color — on by default for Anime.

## Compatibility

- Distant Horizons and Voxy are supported.
- Every setting has a tooltip, and the menu is split into Lighting, Sky, Clouds, Water, Fog and Godrays, Weather, Color, Effects and Performance.

## Using and sharing it

You can use, change and share Gleam under the GNU Lesser General Public License v3.0 (see `LICENSE`), the same license MakeUp UltraFast uses. If you redistribute it, please keep the credit to MakeUp UltraFast and Javier Garduño. You don't need to ask first, though I'd love to hear about it.
