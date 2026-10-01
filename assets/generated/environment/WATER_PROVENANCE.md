# Qingwei water material · 2026-10-01

Original text-to-image material generated for Hero · 渡灯录 with the built-in image-generation tool. No input/reference images, third-party game assets, photographs or stock textures were used. Generated material is not a guarantee of exclusive copyright.

Runtime file `qingwei_water_surface.png`: 1254×1254, RGB, opaque PNG, SHA256 `35ab120dca6fefeafb4bbf8c35a04955398bf9bbe26140d32bb143c298a97702`. Source copied unchanged. This is a static painted water surface; existing procedural pond/channel ripples supply the small animation. No seamless-tiling claim is made or needed: each water polygon samples a single centered region of the texture.

Runtime mapping preserves texture aspect ratio in both the oval pond and narrow river channel. Cached64-point pond boundary and the existing4-point inner-channel polygon clip the painting without changing collision/navigation. The shore treatment blends over existing earth detail; piers, moored skiff, lily pads, reeds and the lightness islet retain their current geometry. This increment does not replace those props or other regions' art. The material is alpha-blended over the original water base (pond0.72, channel0.66) and does not allocate new textures each frame.

## Exact generation prompt

Use case: stylized-concept
Asset type: original overhead WATER MATERIAL texture for the 2D Chinese wuxia RPG Hero / 渡灯录.
Create a square opaque painterly texture showing ONLY the surface of a quiet shallow jade-green river in soft daytime light, viewed from directly above. No horizon and no perspective recession.
Art direction: restrained detailed hand-painted game material, muted sage/jade/teal pigments, soft small irregular water ripples, delicate broken light reflections, slight deeper-green variation beneath the surface. Calm warm atmosphere that belongs beside ink-edged painted willow trees and ochre timber buildings.
Color/contrast: medium-light sage-green base approximately RGB105,150,131, subtle cool teal depths and sparse pale warm-green glints. Keep overall contrast low enough for readable small characters, lily pads and a pier over it. Avoid a bright central highlight or radial spotlight. Detail should be distributed evenly across the square.
Composition: water fills the complete image edge to edge. No shoreline, land, stones, plants, fish, boats, docks, buildings, people, moon, sky, labels, letters, logos, border or UI. No large waves, white foam, photoreal caustics, glossy plastic, swimming-pool grid or vector circles.
This is a water material, not an illustration of a lake; the game supplies its own exact shoreline geometry. Opaque background, natural painted surface with no baked cast shadows.
