# yDream Shaders

yDream is a shader pack for people who want Minecraft to look beautiful without needing a monster GPU. It is built on the fast rendering core of [MakeUp UltraFast](https://github.com/javiergcim/MakeUpUltraFast) by Javier Garduño, but the sky, clouds, water, lighting, color and planetary atmospheres are all its own. Almost everything can be changed in the settings.

Requires Iris 1.5.1 or newer, or OptiFine.
Tested only on Minecraft NeoForge 1.21.1

## Pick your look

yDream has four styles. You can combine any style with a color scheme, a performance profile and the individual settings.

- **Cinematic** is the default: a cool filmic grade with film grain, a vignette, soft shadows and strong godrays, built for screenshots and atmosphere.
- **Vanilla** keeps Minecraft's own sun, moon, stars and blocky clouds, then cleans up the lighting around them.
- **Realistic** aims for a photograph: a physically shaped daytime sky, a small sun and moon at believable size, neutral color and a natural tone curve.
- **Custom** lets you set every sky, light and water color yourself.

Ten color schemes change the whole palette (sky, light, sunsets, night and aurora): Golden Hour, Arctic, Neon Dusk, Crimson Ember, Pastel Dream, Tropical Lagoon, Violet Twilight, Misty Forest, Desert Gold and Midnight Blue. Choose "Style default" to keep the style's own colors.

## TODO
- Cosmonautics Compability
- Ad Astra Compability
- Clouds fixes

- *more mods compability*

## Performance

Six quality profiles set a complete preset in one click: **Potato**, **Swift**, **Standard**, **Polished**, **Ultra** and **Showcase**. Showcase maxes out every effect and forces the shadow sliders to their highest values. It is meant for screenshots only and is not suitable for normal play.

Performance mode trades a little detail for frame rate: **Quality** (full steps), **Balanced**, **Fast** (the default) and **Max FPS**. Fast and Max FPS reduce the ray steps used for clouds, reflections, godrays and ambient occlusion.

Fine-tuning sliders control cloud, godray, reflection and ambient occlusion detail, along with shadow quality and distance. Heavy experimental features such as sun bounce light and global illumination are under Experimental and cost extra frame rate.

## Sky and night

- A round or vanilla-sprite sun with glow, halo and sunset glow, and a round or vanilla-sprite moon with all eight phases, glow and tint.
- Sunrises and sunsets follow the real height of the sun, with a golden-hour blend.
- Stars with twinkle, sparkle and density controls, hero stars, glowing constellation lines and faint nebula wisps.
- Night looks: Natural or Enchanted, with adjustable night color, glow, darkness, airglow and moonlight richness.
- Shooting stars with control over amount, frequency, brightness, trail length, speed and color (presets, aurora colors, rainbow or your own RGB).
- Meteor shower mode for a night full of shooting stars.
- Auroras with palettes (eight presets plus a custom palette), speed, rays, thickness, height, patchiness, shimmer and direction. You choose whether they appear only in snowy biomes or everywhere.
- A rainbow after rain, when the sun is low.
- Lens flare with ghosts, a halo ring and an anamorphic streak.

## Clouds

Choose one of five cloud types, or turn clouds off:

- **Vanilla blocks** keeps Minecraft's cloud mesh with soft, height-shaded lighting. Fast draws one flat layer, Fancy draws the full 3D blocks.
- **Volumetric soft** and **Volumetric detailed** are ray-marched volumetric clouds that light themselves from the sun and shade their own undersides.
- **Volumetric rounded** is a rounded-shape variant of the volumetric clouds.

Cloud controls include speed, density, brightness, shadow strength on the ground, a thin cirrus layer high above, and for vanilla clouds the roundness, cell size, softness, opacity, shading and distance fade. Clouds also show up in water reflections.

## Light and shadows

- Sunlight and moonlight intensity, ambient strength, night brightness, cave brightness, and torch warmth from yellow to pale white.
- Shadows with simple, soft, or pixelated (world-locked) filtering, plus quality, distance, softness and a resolution lock option.
- Colored shadows through stained glass and translucent blocks.
- Ambient occlusion, sky-aware ambient light, and a dynamic light around held glowing items.
- Glowing ore veins, emissive blocks with richness, a white-hot core and a night boost.
- Ground fog that thickens at dawn, dusk and in the rain, with density and height controls.
- Aerial perspective: distant terrain fades toward the sky color before the fog takes over.
- Rain wetness that darkens and sheens exposed surfaces, then dries after the storm.
- Waving plants, with strength and speed controls.

### Experimental

- **Sun bounce light** (overworld only) spreads soft colored light from sunlit ground and walls into nearby shadows.
- **Global illumination** lets light from glowing blocks spread through the world, tinting nearby surfaces and the air in the source's own color. Soul torches, sea lanterns, redstone lamps, froglights, colored candles and lit stained glass all contribute.
- **Material mode** supports LabPBR resource packs or an integrated experimental PBR mode, with normals, specular, metals, emission and parallax occlusion mapping (POM) for surface depth.

## Water

- Water color presets (Clear blue, Deep ocean, Turquoise, Emerald, or Custom), with one color that drives both the water surface and the underwater fog, so they always match.
- Reflections in three modes: sky only, fast screen-space mirror, or raymarched.
- Shallow-to-deep color, absorption, shore foam, refraction and a water texture option.
- Sun reflection, glint and glitter on the surface.
- Underwater fog that absorbs red first and gets darker with depth, with adjustable density and brightness, plus light shafts that reach below the surface.

## Fog, godrays and atmosphere

- Fog with adjustable density, sun scattering, golden tint, saturation and brightness.
- Godrays with strength, buildup, warmth, spread and sharpness controls, a colored godray option, and volumetric godrays that need shadows enabled.
- Atmospheric haze with its own distance and strength controls.

## Weather

- Rain atmosphere strength and rain opacity.
- Rain wetness effects, with strength controls.

## Color and effects

- Tone mapping: Style default, yDream, Natural or Filmic.
- Exposure, saturation, contrast, warmth, tint, vibrance, foliage saturation and foliage brightness.
- Color grading: a filter (None, Sepia, Noir, Teal & Orange, Pastel or Sunset Glow) with strength, plus shadow, highlight, gamma, fade and highlight rolloff controls.
- Bloom with intensity, threshold, radius, saturation, a wide bloom layer and daytime suppression.
- Chromatic aberration, depth of field and motion blur, each with its own strength controls.
- Vignette, film grain, and cinematic letterbox bars that slide in while you sneak and out again when you stand up. The letterbox ratio is adjustable.
- Sharpening and image sharpening, plus an anti-banding option.
- Cartoon ink outlines around silhouettes, with strength, thickness, distance, color and cel shading (color bands) controls.
- Color-blind modes for protanopia, deuteranopia and tritanopia.
- Enchantment glint color: Vanilla, a custom color, a rainbow, or matching your color scheme, with strength and speed controls.
- Retro pixelation mode.

## Dimensions

**Overworld:** everything above.

**The Nether:** an ember-filled atmosphere with adjustable fog distance, drifting embers (with amount and color modes: fire orange, soul blue, crimson, warped teal or golden), a glowing haze, and star brightness. Nether clouds follow the same volumetric cloud settings as the overworld, and the Nether uses the overworld star layer.

**The End:** a self-contained End atmosphere with three sky palettes (Molten dusk, Violet abyss, Ash and ember), sky depth, horizon glow, vertical heat, and a planetary core you can turn on or off. The core has three palettes (Molten orange, Bright magma, Deep mantle), adjustable size and intensity, optional purple corruption lines with their own count and palette, and a warm scene light.


## Compatibility

- Distant Horizons and Voxy are supported.
- Northstar planets (requires the Northstar mod):** Mercury, Venus, Mars, the Moon and the orbital dimensions each have their own atmosphere presets, sky colors, haze and sun size.
- **Moon:** sky colors, haze, neutral sunlight and a small shadow floor.
- **Mars:** a tawny dust-haze sky with a blue aureole around the sun, adjustable dust optical depth and daylight strength. Stars low on the horizon are dimmed by the dust.
- **Venus:** a dense, amber, cloud-filtered sky with a diffuse solar glow. Cloud opacity and warm ground light are adjustable.
- **Mercury:** a very large apparent sun, with its own sky colors and haze.
- **Orbit:** planets and the sun are drawn with their correct brightness from the NASA solar flux values, sun size scales with orbital distance, and the planet brightness and maximum brightness are adjustable.

Each planet can show or hide the Northstar suns and clouds independently, and planet atmosphere presets can be turned off entirely.

## Credits

yDream Shaders is built on the MakeUp UltraFast codebase by Javier Garduño ([github.com/javiergcim/MakeUpUltraFast](https://github.com/javiergcim/MakeUpUltraFast)), distributed under the GNU Lesser General Public License v3.0. The base architecture and several lower-level techniques come from that project.

yDream is based on Gleam and only works the way I want it to thanks to the beautiful custom stars and clouds created by Gleam's author, [FihMC](https://modrinth.com/user/FihMC)

Some of the code is inspired by work from:

- Capt Tatsu, enhanced ambient occlusion from [BSL Shaders](https://bitslablab.com/bslshaders/).
- Emin and gri573, shadow bias technique ([complementary.dev](https://www.complementary.dev/)).
- Erkaman, TAA based on [a simple TAA implementation](https://gist.github.com/Erkaman).
- Interleaved noise from [*Next Generation Post Processing in Call of Duty: Advanced Warfare*](http://advances.realtimerendering.com/s2014/index.html).
- delu and TinyTexel, phi noise ([Shadertoy](https://www.shadertoy.com/view/Nst3R7)).
- atyuwen, Dither 13 and Dither 17 ([Shadertoy](https://www.shadertoy.com/view/wl3cWX)).

The NASA Planetary Fact Sheet provided the solar and atmospheric values used for the Northstar planets.

## Using and sharing it

You can use, change and share yDream under the GNU Lesser General Public License v3.0 (see `LICENSE`), the same license MakeUp UltraFast uses. If you redistribute it, please keep the credit to MakeUp UltraFast and Javier Garduño. You don't need to ask first, though I'd love to hear about it.