# Golden reference fish — first model study

Based on the side-view image supplied by the user. Front/top shapes are inferred, not additional source photographs. This is original procedural mesh modeling in Unity, not an image-to-3D service output or a downloaded Sketchfab model. Rights in the supplied reference image are not determined here.

- Source image: `golden-fish-user-reference.png`.
- Actual orthographic model render: `golden-reference-three-views.png` (front, right-facing side, top).
- Prefab: `Assets/Resources/OpenSea/Fish/GoldenReference.prefab`.
- Saved mesh/material/texture assets: `Assets/Art/GoldenReferenceFish/`.
- Recreate and render: **Chinsekid → Fish Game → Create Golden Reference Fish**.
- `GoldenReferenceFishMotion` animates tail yaw and paired pectoral fins; `OpenSeaFishVisual` forwards the normal/boost animation state.
- Skin resource mapping: `goldenReference` → `GoldenReference`. Included in the random fish species at all levels, with three guaranteed members in the initial school. The native skin picker includes this model with an actual Unity-rendered thumbnail (金鳞鱼, level 2 unlock).

The mesh faces +Z and uses world units compatible with the existing fish actors. Tail/fin transforms animate separately; no skeleton or external 3D software is required. Unity editor import and still rendering completed; no App build or on-device animation/performance verification was performed.
