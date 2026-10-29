using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Chinsekid.FishGame.Editor
{
    static class OpenSeaAssetSetup
    {
        const string Source = "Assets/ThirdParty/QuaterniusCuteFish/Models";
        const string Materials = "Assets/ThirdParty/QuaterniusCuteFish/Materials";
        const string Prefabs = "Assets/Resources/OpenSea/Fish";
        const string Environment = "Assets/Resources/OpenSea/Environment";
        public static readonly string[] FishNames = {
            "Clownfish", "BlueTang", "ButterflyFish", "CoralGrouper", "Goldfish", "Koi",
            "Puffer", "Shark", "RoyalGramma", "Anglerfish", "Lionfish", "Tang"
        };

        [MenuItem("Chinsekid/Fish Game/Prepare Downloaded Sea Assets")]
        public static void Prepare()
        {
            Directory.CreateDirectory(Materials);
            Directory.CreateDirectory(Prefabs);
            Directory.CreateDirectory(Environment);
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            foreach (string name in FishNames) PrepareFish(name);
            PrepareGround("coast_sand_02", "Seabed", new Color(.52f, .68f, .72f), new Vector2(16, 13));
            PrepareGround("rock_3", "ReefRock", new Color(.62f, .76f, .78f), Vector2.one * 2);
            AssetDatabase.SaveAssets();
            Debug.Log("[OpenSea] Prepared 12 CC0 fish prefabs and 2 textured seabed materials. No player build was run.");
        }

        static void PrepareFish(string name)
        {
            string path = Source + "/" + name + ".fbx";
            var importer = AssetImporter.GetAtPath(path) as ModelImporter;
            if (importer == null) throw new InvalidOperationException("Missing downloaded FBX: " + path);
            bool changed = importer.animationType != ModelImporterAnimationType.Legacy || !importer.importAnimation
                || importer.materialImportMode != ModelImporterMaterialImportMode.ImportStandard
                || importer.importCameras || importer.importLights || importer.addCollider;
            importer.animationType = ModelImporterAnimationType.Legacy;
            importer.importAnimation = true;
            importer.importCameras = false;
            importer.importLights = false;
            importer.addCollider = false;
            importer.materialImportMode = ModelImporterMaterialImportMode.ImportStandard;
            if (changed) importer.SaveAndReimport();
            var clips = importer.defaultClipAnimations
                .Where(c => c.name.Contains("Swimming_Normal") || c.name.Contains("Swimming_Fast")).ToArray();
            if (clips.Length == 0) throw new InvalidOperationException("No swimming animation in " + name);
            foreach (var clip in clips) { clip.loopTime = true; clip.wrapMode = WrapMode.Loop; }
            if (importer.clipAnimations.Length != clips.Length || importer.clipAnimations.Any(c => !c.loopTime))
            {
                importer.clipAnimations = clips;
                importer.SaveAndReimport();
            }

            var source = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            var root = new GameObject(name);
            try
            {
                var alignment = new GameObject("Normalized model").transform;
                alignment.SetParent(root.transform, false);
                var instance = UnityEngine.Object.Instantiate(source, alignment);
                instance.name = "Animated " + name;
                SmoothFishMeshSetup.Apply(instance, name);
                foreach (var animation in instance.GetComponentsInChildren<Animation>(true))
                {
                    var normalPose = AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>()
                        .First(c => c.name.Contains("Swimming_Normal") && !c.name.StartsWith("__preview__"));
                    normalPose.SampleAnimation(animation.gameObject, 0);
                }
                var renderers = instance.GetComponentsInChildren<Renderer>(true);
                Bounds bounds = GetBounds(renderers);
                Debug.Log("[OpenSeaSource] " + name + " " + bounds);
                // Determine the head from the artist's eye submesh, rather than
                // assuming that every FBX exporter uses the same forward axis.
                Vector3 eyes = Vector3.zero;
                int eyeVertices = 0;
                foreach (var renderer in renderers)
                {
                    var skin = renderer as SkinnedMeshRenderer;
                    var filter = renderer.GetComponent<MeshFilter>();
                    var mesh = skin != null ? skin.sharedMesh : filter != null ? filter.sharedMesh : null;
                    if (mesh == null) continue;
                    var sourceMaterials = renderer.sharedMaterials;
                    var vertices = mesh.vertices;
                    for (int i = 0; i < Mathf.Min(mesh.subMeshCount, sourceMaterials.Length); i++)
                        if (sourceMaterials[i] != null && sourceMaterials[i].name.IndexOf("eye", StringComparison.OrdinalIgnoreCase) >= 0)
                            foreach (int index in mesh.GetTriangles(i).Distinct())
                            {
                                eyes += renderer.transform.TransformPoint(vertices[index]);
                                eyeVertices++;
                            }
                }
                if (eyeVertices == 0) throw new InvalidOperationException("Cannot identify head direction: " + name);
                Vector3 heading = eyes / eyeVertices - bounds.center;
                heading.y = 0;
                if (heading.sqrMagnitude < .00001f) throw new InvalidOperationException("Ambiguous model heading: " + name);
                alignment.rotation = Quaternion.FromToRotation(heading.normalized, Vector3.forward);
                bounds = GetBounds(renderers);
                float scale = Mathf.Min(2.65f / bounds.size.z, 1.65f / bounds.size.x, 1.65f / bounds.size.y);
                alignment.localScale = Vector3.one * scale;
                alignment.localPosition = -bounds.center * scale;

                foreach (var renderer in renderers)
                {
                    renderer.shadowCastingMode = ShadowCastingMode.Off;
                    renderer.receiveShadows = false;
                    var slots = renderer.sharedMaterials;
                    for (int i = 0; i < slots.Length; i++)
                    {
                        var original = slots[i];
                        if (original == null) continue;
                        string materialName = name + "_" + original.name.Replace("/", "_");
                        string materialPath = Materials + "/" + materialName + ".mat";
                        var material = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
                        if (material == null)
                        {
                            material = new Material(Shader.Find("Standard")) { name = materialName };
                            AssetDatabase.CreateAsset(material, materialPath);
                        }
                        // FBX stores the Blender diffuse values in linear space.
                        material.color = original.color.gamma;
                        material.mainTexture = original.mainTexture;
                        material.SetFloat("_Metallic", 0);
                        material.SetFloat("_Glossiness", original.name.Contains("Eyes") ? .75f : .32f);
                        EditorUtility.SetDirty(material);
                        slots[i] = material;
                    }
                    renderer.sharedMaterials = slots;
                    if (renderer is SkinnedMeshRenderer skinned) skinned.updateWhenOffscreen = false;
                }
                foreach (var animation in instance.GetComponentsInChildren<Animation>(true))
                {
                    var normal = AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>()
                        .First(c => c.name.Contains("Swimming_Normal") && !c.name.StartsWith("__preview__"));
                    animation.clip = normal;
                    animation.playAutomatically = true;
                    animation.wrapMode = WrapMode.Loop;
                    animation.cullingType = AnimationCullingType.BasedOnRenderers;
                }
                PrefabUtility.SaveAsPrefabAsset(root, Prefabs + "/" + name + ".prefab");
                Debug.Log("[OpenSea] " + name + " heading=" + heading.normalized + " bounds=" + GetBounds(renderers).size);
            }
            finally { UnityEngine.Object.DestroyImmediate(root); }
        }

        static Bounds GetBounds(Renderer[] renderers)
        {
            if (renderers.Length == 0) throw new InvalidOperationException("Model has no renderers");
            var bounds = new Bounds();
            bool first = true;
            foreach (var renderer in renderers)
            {
                var skin = renderer as SkinnedMeshRenderer;
                var filter = renderer.GetComponent<MeshFilter>();
                var mesh = skin != null ? skin.sharedMesh : filter != null ? filter.sharedMesh : null;
                if (mesh != null)
                    foreach (var vertex in mesh.vertices)
                    {
                        Vector3 world = renderer.transform.TransformPoint(vertex);
                        if (first) { bounds = new Bounds(world, Vector3.zero); first = false; }
                        else bounds.Encapsulate(world);
                    }
            }
            if (first) throw new InvalidOperationException("Model has no mesh vertices");
            return bounds;
        }

        static void PrepareGround(string source, string name, Color tint, Vector2 tiling)
        {
            string folder = "Assets/ThirdParty/PolyHaven/Textures/";
            string diffusePath = folder + source + "_diff_1k.jpg";
            string normalPath = folder + source + "_nor_gl_1k.jpg";
            foreach (string path in new[] { diffusePath, normalPath })
            {
                var importer = AssetImporter.GetAtPath(path) as TextureImporter;
                if (importer == null) throw new InvalidOperationException("Missing downloaded texture: " + path);
                var type = path == normalPath ? TextureImporterType.NormalMap : TextureImporterType.Default;
                if (importer.textureType != type || importer.maxTextureSize != 1024 || importer.wrapMode != TextureWrapMode.Repeat)
                {
                    importer.textureType = type;
                    importer.maxTextureSize = 1024;
                    importer.wrapMode = TextureWrapMode.Repeat;
                    importer.mipmapEnabled = true;
                    importer.anisoLevel = 2;
                    importer.SaveAndReimport();
                }
            }
            string target = Environment + "/" + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(target);
            if (material == null)
            {
                material = new Material(Shader.Find("Standard"));
                AssetDatabase.CreateAsset(material, target);
            }
            material.color = tint;
            material.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(diffusePath);
            material.mainTextureScale = tiling;
            material.SetTexture("_BumpMap", AssetDatabase.LoadAssetAtPath<Texture2D>(normalPath));
            material.SetTextureScale("_BumpMap", tiling);
            material.SetFloat("_BumpScale", .65f);
            material.SetFloat("_Metallic", 0);
            material.SetFloat("_Glossiness", .12f);
            material.EnableKeyword("_NORMALMAP");
            EditorUtility.SetDirty(material);
        }
    }
}
