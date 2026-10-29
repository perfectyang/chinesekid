using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Chinsekid.FishGame.Editor
{
    static class FishGameProjectSetup
    {
        [MenuItem("Chinsekid/Fish Game/Create Build Scene")]
        public static void CreateBuildScene()
        {
            const string folder = "Assets/Scenes";
            const string scenePath = folder + "/FishGame.unity";
            if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);
            EnsureGameScene(scenePath);
            AssetDatabase.Refresh();
        }

        [MenuItem("Chinsekid/Fish Game/Render Meat Preview")]
        public static void RenderMeatPreview()
        {
            EnsureRuntimeMaterials();
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var pickup = new GameObject("Meat preview").AddComponent<MeatPickup>();
            pickup.Initialize(Vector3.zero, Vector3.zero);
            pickup.Tick(1f);
            var light = new GameObject("Preview light", typeof(Light)).GetComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = .9f;
            light.transform.rotation = Quaternion.Euler(45f, -25f, 0f);
            var camera = new GameObject("Preview camera", typeof(Camera)).GetComponent<Camera>();
            camera.transform.position = new Vector3(0f, 2.5f, -3.5f);
            camera.transform.LookAt(new Vector3(0f, .25f, 0f));
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(.06f, .20f, .27f);
            camera.orthographic = true;
            camera.orthographicSize = 1.45f;
            var renderTexture = new RenderTexture(512, 512, 24);
            camera.targetTexture = renderTexture;
            camera.Render();
            RenderTexture.active = renderTexture;
            var preview = new Texture2D(512, 512, TextureFormat.RGB24, false);
            preview.ReadPixels(new Rect(0, 0, 512, 512), 0, 0);
            preview.Apply();
            File.WriteAllBytes("/tmp/chinsekid-meat-preview.png", preview.EncodeToPNG());
            camera.targetTexture = null;
            RenderTexture.active = null;
            renderTexture.Release();
            UnityEngine.Object.DestroyImmediate(renderTexture);
            UnityEngine.Object.DestroyImmediate(preview);
            UnityEngine.Object.DestroyImmediate(camera.gameObject);
            UnityEngine.Object.DestroyImmediate(light.gameObject);
            UnityEngine.Object.DestroyImmediate(pickup.gameObject);
        }

        [MenuItem("Chinsekid/Fish Game/Export iOS Xcode Project")]
        public static void ExportIOSXcodeProject()
        {
            ExportIOSXcodeProject("Build/UnityFishGame-iOS", iOSSdkVersion.DeviceSDK);
        }

        [MenuItem("Chinsekid/Fish Game/Export iOS Simulator Xcode Project")]
        public static void ExportIOSSimulatorXcodeProject()
        {
            var previousSdk = PlayerSettings.iOS.sdkVersion;
            var previousSimulatorArchitecture = PlayerSettings.iOS.simulatorSdkArchitecture;
            var previousCodeGeneration = PlayerSettings.GetIl2CppCodeGeneration(NamedBuildTarget.iOS);
            try
            {
                PlayerSettings.iOS.simulatorSdkArchitecture = AppleMobileArchitectureSimulator.ARM64;
                PlayerSettings.SetIl2CppCodeGeneration(NamedBuildTarget.iOS, Il2CppCodeGeneration.OptimizeSpeed);
                ExportIOSXcodeProject("Build/UnityFishGame-iOS-Simulator", iOSSdkVersion.SimulatorSDK);
            }
            finally
            {
                PlayerSettings.iOS.sdkVersion = previousSdk;
                PlayerSettings.iOS.simulatorSdkArchitecture = previousSimulatorArchitecture;
                PlayerSettings.SetIl2CppCodeGeneration(NamedBuildTarget.iOS, previousCodeGeneration);
            }
        }

        static void ExportIOSXcodeProject(string exportFolder, iOSSdkVersion sdkVersion)
        {
            const string scenePath = "Assets/Scenes/FishGame.unity";
            var previousSdk = PlayerSettings.iOS.sdkVersion;
            PlayerSettings.iOS.sdkVersion = sdkVersion;
            EnsureGameScene(scenePath);

            try
            {
                var options = new BuildPlayerOptions
                {
                    scenes = new[] { scenePath },
                    locationPathName = Path.GetFullPath(exportFolder),
                    target = BuildTarget.iOS,
                    options = BuildOptions.None
                };
                var report = BuildPipeline.BuildPlayer(options);
                if (report.summary.result != BuildResult.Succeeded)
                {
                    throw new InvalidOperationException("Unity iOS Xcode project export failed: " + report.summary.result);
                }
            }
            finally
            {
                PlayerSettings.iOS.sdkVersion = previousSdk;
            }
        }

        static void EnsureGameScene(string scenePath)
        {
            OpenSeaAssetSetup.Prepare();
            EnsureRuntimeMaterials();
            Scene scene;
            if (File.Exists(scenePath))
            {
                scene = EditorSceneManager.OpenScene(scenePath, OpenSceneMode.Single);
            }
            else
            {
                scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            }

            if (UnityEngine.Object.FindFirstObjectByType<FishGameManager>() == null)
            {
                var gameRoot = new GameObject("Chinsekid 3D Fish Game");
                gameRoot.AddComponent<FishGameManager>();
            }

            EditorSceneManager.SaveScene(scene, scenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(scenePath, true) };
        }

        static void EnsureRuntimeMaterials()
        {
            // Runtime Shader.Find alone does not cause a shader to be packaged.
            // Resource materials retain both normal and glowing Standard variants.
            if (!AssetDatabase.IsValidFolder("Assets/Resources"))
                AssetDatabase.CreateFolder("Assets", "Resources");
            var shader = Shader.Find("Standard");
            if (shader == null) throw new InvalidOperationException("Standard shader is unavailable");
            foreach (var name in new[] { "FishSurface", "FishGlow" })
            {
                var path = "Assets/Resources/" + name + ".mat";
                if (AssetDatabase.LoadAssetAtPath<Material>(path) != null) continue;
                var material = new Material(shader);
                if (name == "FishGlow")
                {
                    material.EnableKeyword("_EMISSION");
                    material.SetColor("_EmissionColor", Color.white);
                }
                AssetDatabase.CreateAsset(material, path);
            }
            AssetDatabase.SaveAssets();
        }
    }
}
