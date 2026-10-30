 <div align="center">
  <img src="https://raw.githubusercontent.com/neekometria/yDream/refs/heads/main/yDream.png" alt="yDream Shaders" width="900">

  <p>
    <strong>Ad Astra Per Aspera.</strong>
  </p>

  <p>
    A cinematic and highly customizable visual experience for Minecraft.
    Explore new skies, dynamic lighting, volumetric clouds and planetary atmospheres
    without needing a high-end GPU.
  </p>

  <p>
    <img src="https://img.shields.io/badge/Minecraft-1.21.1-brightgreen?style=for-the-badge" alt="Minecraft 1.21.1">
    <img src="https://img.shields.io/badge/NeoForge-Tested-blue?style=for-the-badge" alt="Tested on NeoForge">
    <img src="https://img.shields.io/badge/Iris-1.5.1%2B-purple?style=for-the-badge" alt="Iris 1.5.1 or newer">
    <img src="https://img.shields.io/badge/OptiFine-Compatible-orange?style=for-the-badge" alt="OptiFine compatible">
  </p>

  <p>
    <img src="https://img.shields.io/badge/Distant%20Horizons-Supported-blue?style=flat-square" alt="Distant Horizons Supported">
    <img src="https://img.shields.io/badge/Voxy-Supported-blue?style=flat-square" alt="Voxy Supported">
    <img src="https://img.shields.io/badge/Northstar-Integration-9cf?style=flat-square" alt="Northstar Integration">
  </p>

  <p>
    <img src="https://img.shields.io/badge/Language-PT%2FEN%2FJP-blue?style=flat-square" alt="Portuguese, English and Japanese">
  </p>

</div>

---

> **yDream Shaders** requires **Iris 1.5.1 or newer**, or **OptiFine**.
> Tested on Minecraft **1.21.1 with NeoForge**.
> Created with Create Aeronautics in mind.

> Built upon the fast rendering core of [MakeUp UltraFast](https://github.com/javiergcim/MakeUpUltraFast), with custom visual systems and atmospheric features. Also based on [Gleam Shaders](https://modrinth.com/mod/gleam-shaders), with credits to its [original creator](https://modrinth.com/user/FihMC).

<img src="https://raw.githubusercontent.com/neekometria/yDream/refs/heads/main/banner_2.png" alt="yDream Shaders" width="900">

## Cinematic Experience

yDream has one style, but very customizable.

Ten color schemes change the whole palette (sky, light, sunsets, night and aurora): Golden Hour, Arctic, Neon Dusk, Crimson Ember, Pastel Dream, Tropical Lagoon, Violet Twilight, Misty Forest, Desert Gold and Midnight Blue. Choose "Style default" to keep the style's own colors.

## TODO
- Clouds adjustment
- True atmosphere after clouds
- Cosmonautics Compability
- Ad Astra Compability
- Better TAA
- Better overworld tonemapping

- *more mods integrations*

## Compatibility

- Distant Horizons and Voxy are supported.
- **Northstar planets (requires the Northstar mod):** Mercury, Venus, Mars, the Moon and the orbital dimensions each have their own atmosphere presets, sky colors, haze and sun size.
- **Moon:** sky colors, haze, neutral sunlight and a small shadow floor.
- **Mars:** a tawny dust-haze sky with a blue aureole around the sun, adjustable dust optical depth and daylight strength. Stars low on the horizon are dimmed by the dust.
- **Venus:** a dense, amber, cloud-filtered sky with a diffuse solar glow. Cloud opacity and warm ground light are adjustable.
- **Mercury:** a very large apparent sun, with its own sky colors and haze.
- **Orbit:** planets and the sun are drawn with their correct brightness from the NASA solar flux values, sun size scales with orbital distance, and the planet brightness and maximum brightness are adjustable.
> Each planet can show or hide the Northstar suns and clouds independently, and planet atmosphere presets can be turned off entirely.

## Performance

Performance mode trades a little detail for frame rate: **Quality** (full steps), **Balanced**, **Fast** (the default) and **Max FPS**. Fast and Max FPS reduce the ray steps used for clouds, reflections, godrays and ambient occlusion.

Fine-tuning sliders control cloud, godray, reflection and ambient occlusion detail, along with shadow quality and distance. Heavy experimental features such as sun bounce light and global illumination are under Experimental and cost extra frame rate.

All screenshots were taken using a GTX 750TI.
Simple benchmarks show a 5%–10% performance improvement compared to Gleam using the Polished and default preset.

## Dimensions

**Overworld:** everything above.

**The Nether:** an ember-filled atmosphere with adjustable fog distance, drifting embers (with amount and color modes: fire orange, soul blue, crimson, warped teal or golden), a glowing haze, and star brightness. Nether clouds follow the same volumetric cloud settings as the overworld, and the Nether uses the overworld star layer.

**The End:** a self-contained End atmosphere with three sky palettes (Molten dusk, Violet abyss, Ash and ember), sky depth, horizon glow, vertical heat, and a planetary core you can turn on or off. The core has three palettes (Molten orange, Bright magma, Deep mantle), adjustable size and intensity, optional purple corruption lines with their own count and palette, and a warm scene light.


<img src="https://raw.githubusercontent.com/neekometria/yDream/refs/heads/main/banner_3.png" alt="yDream Shaders" width="900">


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