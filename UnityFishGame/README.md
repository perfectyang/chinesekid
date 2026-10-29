# Chinsekid Unity Fish Game

This is the first Unity 3D gameplay port for the existing iPad fish game. It keeps the original app as the owner of profiles, alphabet practice, and the two-ticket entry rule. Unity owns the 3D scene, touch steering, fish AI, growth, collisions, and in-game visuals.

## Preview in Unity

1. Open this folder from Unity Hub with Unity 6.6.6f1. This project was upgraded from 6.0.65f1 for the iOS export.
2. In Unity, choose **Chinsekid → Fish Game → Create Build Scene**. This makes the scene and registers it for iOS export.
3. Press Play. The scene's `FishGameManager` starts the playable scene.
4. Drag on the water to steer. Hold the blue boost button for a speed burst.

Fish use 12 downloaded Quaternius animated models with their original species colors. Sand and rocks use Poly Haven color and normal maps (1K). Shrimp, octopus, coral and plants still use generated meshes. The camera follows the player, and fish turn smoothly through full rotations. Asset sources and CC0 licenses are recorded in `Assets/ThirdParty/ASSET-SOURCES.md`.

**Prepare Downloaded Sea Assets** imports the FBX swimming clips, normalizes orientation and size, and generates Resources prefabs/materials without building a player. **Render Downloaded Fish Preview** renders an editor contact sheet to `/tmp/chinsekid-open-sea-preview.png`. The scene/export setup also prepares these assets automatically. Re-export Unity and rebuild the matching UnityFramework/Data before expecting these changes in the native app.

## iOS export and app integration

Use **Chinsekid → Fish Game → Export iOS Xcode Project**. Unity writes the iOS export to `Build/UnityFishGame-iOS`, including the `Unity-iPhone.xcodeproj` project and its `Data` directory. Build the `UnityFramework` scheme from that Xcode project for a physical iOS device. The resulting framework is copied to `Build/UnityFishGame-iOS/Artifacts/UnityFramework.framework`.

The native `chinsekid` Xcode target embeds that framework in `Frameworks` and copies Unity's `Data` directory into the app bundle. `UnityFishGameRuntimeView.swift` loads the framework from the embedded Frameworks folder. Build the native app from `chinsekid.xcodeproj` after the framework export is present. The checked-in Xcode project references generated files under the ignored `Build` directory, so regenerate the Unity export and framework before building from a clean checkout.

The Unity runtime is full-screen and uses a single runtime instance. The native app continues to own profiles, alphabet practice, and game tickets.

For an Apple Silicon simulator, choose **Export iOS Simulator Xcode Project** and build the exported `Build/UnityFishGame-iOS-Simulator/Unity-iPhone.xcodeproj`. Package the simulator and device frameworks together as `Build/UnityFishGame.xcframework`. The host copies the matching simulator `Data` directory during simulator builds; framework and Data must come from the same export.

`Assets/link.xml` retains native scene-loading callbacks and the component types used internally by `GameObject.CreatePrimitive`. Keep these even though there are no direct gameplay references to every type. The exporter also creates resource materials to include the Standard shader variants used by the dynamically generated scene. Missing callbacks can crash during startup; missing shaders can leave initialization on a black screen.

The iOS plug-in `FishGameNativeBridge.mm` reports final score, level, and fish eaten through the `Chinsekid.UnityFishGameDidFinish` notification. The native host observes that notification, dismisses Unity, and returns to the app's result flow.

## Endless sea and local population

The Unity sea no longer clamps fish or touch targets to the original map limits. `EndlessSeaWorld` recenters sand and caustics beyond the camera footprint and wraps existing reef colonies outside the view. Fish, food, power-ups and hazards are reused around the player; a floating origin keeps long sessions near zero without changing the relative camera, swimming targets or actor positions.

Population maintenance runs every 0.4 seconds, aims for at least 14 visible fish including 9 edible fish, and limits the total to 80. New prey enters near the screen edges at least 6 world units from the player; relocated predators return 28–44 units away with their chase cooldown. Fish-school waves respect the same total limit. Growth/return HUD backgrounds are transparent.

Editor regression check: execute `Chinsekid.FishGame.Editor.EndlessSeaValidation.Run`. It checks portrait/landscape seabed coverage, movement beyond the original bounds, far travel and floating-origin rebasing, visible edible population, fish count limits and transparent HUD panels. This is an editor check, not a real-device performance measurement.
