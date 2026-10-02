# Original Qin He combat art

Generated 2026-10-02 with the built-in image-generation tool. Project-owned identity reference: bottom-right Qin portrait in `hero-character-portraits-atlas.png`. The existing Tang combat atlas supplied painterly material/style only. No external game art was used.

Source retained: `generated_images/exec-5518ac9b-7513-41ec-b971-71f7992ed318.png`
Runtime copy: `assets/generated/characters/painted_qin_combat.png`
PNG RGBA,1536×1024. SHA256 `041c03bd399c50c0d5c1899e0e10470123608cde934a5376a976b3e35dc4d7b0`
Owned portrait reference SHA256 `79a03e824454dbae58088d27d5c3679a1512028ef704cfa18f0c15f907e3e859`
Owned Tang reference SHA256 `15c888915a83b427692411fb1ec4afc2919e8b948edfc5f47b27b9f7e3eaf8a9`

The generated PNG is copied unchanged. Six individually measured runtime crops preserve the extended staff; a naive512px grid would clip the thrust. The helper declares source regions, per-pose foot/weapon anchors and opaque bounds. Bounds use alpha>.08 to include soft material edges. The alpha channel is genuine; hidden RGB contains an underpainting which must not be flattened. Normalization0.86 matches existing actor visual height. Poses are idle, strike, protect, hurt, down and recover; they do not assert a gameplay event by themselves.

## Generation prompt

Use case: identity-preserve / stylized-concept. Asset type: ORIGINAL production 2D wuxia combat sprite atlas on true transparent background. Reference image 1 contains four OWNED character portraits. ONLY the BOTTOM-RIGHT woman is the subject: Qin He, a composed mature Chinese woman with charcoal-gray hair tied into a loose bun, side locks, olive-green weathered short outer robe over cream sleeves, dark green/gray traveling trousers and simple dark leather boots, green hair cord, brown traveling shoulder strap and small satchel, long sturdy bamboo staff. Preserve her face, hair and clothing identity from this bottom-right portrait. Do NOT draw the other three portrait subjects. Reference image 2 is only the desired painterly game-sprite style and detailed textured cloth, not the character. Create six full-body key poses of this SAME woman in EXACTLY 3 equal columns by 2 equal rows, each cell square, total landscape 3:2 canvas ideally1536x1024. Each pose stays strictly in its cell with ample transparent margins. All facing right / 3-quarter right, viewed slightly from above, full head, hands, staff and boots fully visible. Same body scale across poses, standing foot baseline around92% cell height. NO labels or lines or floor shadows. Order: TOP-LEFT calm idle stance holding bamboo staff diagonally; TOP-CENTER forceful rightward staff thrust with two hands and clear planted feet; TOP-RIGHT protecting another ally with staff held horizontally across chest, resolute wide stance, subtle tiny golden qi wisps near staff; BOTTOM-LEFT recoiling from impact, one knee bent, staff lowered, no blood or wound; BOTTOM-CENTER incapacitated but alive resting low on one knee and hand, staff on ground, recognizable silhouette; BOTTOM-RIGHT recovery ready stance raising staff, alert and balanced. Natural anatomy. High-quality painted watercolor-and-ink wuxia RPG sprites with crisp readable silhouettes, soft realistic material shading, slightly stylized proportions, matching existing original Hero assets. True alpha cutouts only, no background color, no checkerboard, no panels, no symbols/text/numbers, no logos, no trademarked imagery, no repeated male companion, no sword, no spear head.

## Original Qin command icons

Source retained: `generated_images/exec-dbe23598-cbfa-431d-8e9a-20120f9afb5e.png`
Runtime copy: `assets/ui/qin_commands_painted_atlas.png`
Opaque PNG1774×887, two887px square cells, copied unchanged.
SHA256 `4c70a4f1903c2eccd1a9c9c0113b0964994e28a31a1241195826e75e3ed13b37`
Only actual action descriptors display these images. Descriptive qi artwork adds no gameplay effect.

Prompt: Use case: stylized-concept. Asset type: ORIGINAL hand-painted wuxia game skill icons, exactly two equal square cells side by side in one2:1 landscape atlas, ideally1536x768. Left icon: a sturdy segmented bamboo staff thrusting diagonally right through golden amber brushlight and a few restrained wooden sparks, clean strong silhouette, dark olive-black corners, blunt staff not spear or sword. Right icon: the same long bamboo staff held across a glowing circular bronze-and-jade defensive qi shield, a gentle distant abstract human silhouette safely behind the shield, ripples of pale gold energy, deep teal-dark background. This is a protective martial, not a healing icon: no medical cross, no herbs, no potion. Both cells high material depth and textured painted highlights, strong silhouettes readable at60px, richly colored premium original Chinese ink-fantasy RPG icon family. No text, digits, labels, frame, UI screenshot, watermark, logo, or borrowed franchise imagery. Each illustration stays inside its half. Opaque backgrounds, no margin or gap between cells.
