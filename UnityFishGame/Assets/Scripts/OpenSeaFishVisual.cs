using System;
using System.Collections.Generic;
using UnityEngine;

namespace Chinsekid.FishGame
{
    public sealed class OpenSeaFishVisual : MonoBehaviour
    {
        static readonly string[] Species = {
            "Clownfish", "BlueTang", "ButterflyFish", "CoralGrouper", "Goldfish", "Koi",
            "Puffer", "RoyalGramma", "Tang", "GoldenReference",
            "PatternedReef", "RubyLionfish", "SpottedPuffer", "AzureAngelfish",
            "Shark", "Anglerfish", "Lionfish", "FangHunter", "GrinningShark", "IridescentShark"
        };
        const int SmallFishSpeciesCount = 14;
        static readonly Dictionary<string, GameObject> prefabs = new();
        static readonly Dictionary<string, int> nextWildColor = new();
        static readonly float[] WildHueOffsets = { 0f, .13f, .34f, .56f, .77f };
        readonly List<(Animation animation, string normal, string fast)> swimmers = new();
        static readonly Dictionary<string, float> bodyScales = new();
        static readonly Dictionary<string, Vector3> bodyCenters = new();
        bool fastSwimming;
        GoldenReferenceFishMotion referenceMotion;

        public static string ModelForSkin(string skin) => skin switch
        {
            "goldenReference" => "GoldenReference",
            "patternedReef" => "PatternedReef",
            "rubyLionfish" => "RubyLionfish",
            "spottedPuffer" => "SpottedPuffer",
            "azureAngelfish" => "AzureAngelfish",
            "fangHunter" => "FangHunter",
            "grinningShark" => "GrinningShark",
            "iridescentShark" => "IridescentShark",
            "yellowTang" => "Tang",
            "puffer" or "tealPuffer" => "Puffer",
            "butterfly" => "ButterflyFish",
            "tang" or "blueMinnow" => "BlueTang",
            "shark" or "reefShark" => "Shark",
            "angler" => "Anglerfish",
            "stripedCoral" => "RoyalGramma",
            "redfin" => "Goldfish",
            "silverfish" => "Koi",
            "longfinFish" => "Lionfish",
            "green" => "CoralGrouper",
            _ => "Clownfish"
        };

        public static Transform Create(Transform parent, int level, string selectedModel = null, bool isPlayer = false)
        {
            string name = selectedModel ?? Species[UnityEngine.Random.Range(0, level >= 3 ? Species.Length : SmallFishSpeciesCount)];
            if (!prefabs.TryGetValue(name, out var prefab) || prefab == null)
                prefabs[name] = prefab = Resources.Load<GameObject>("OpenSea/Fish/" + name);
            if (prefab == null)
            {
                Debug.LogWarning("[OpenSea] Missing fish prefab " + name + ". Run Prepare Downloaded Sea Assets in the Unity editor.");
                return null;
            }
            var instance = Instantiate(prefab, parent, false);
            if (!isPlayer) ApplyWildColor(instance, name);
            // Equalize the trunk's projected area, not its length. A round puffer
            // and a slender shark must occupy comparable space at the same level.
            if (!bodyScales.TryGetValue(name, out float bodyScale))
            {
                Bounds body = MeasureBody(instance);
                bodyScale = Mathf.Sqrt(1.05f / ProjectedBodyArea(body.size));
                bodyScales[name] = bodyScale;
                bodyCenters[name] = body.center;
            }
            instance.transform.localScale *= bodyScale;
            instance.transform.localPosition = -bodyCenters[name] * bodyScale;
            instance.name = "Fish model " + name;
            var visual = instance.AddComponent<OpenSeaFishVisual>();
            visual.referenceMotion = instance.GetComponent<GoldenReferenceFishMotion>();
            foreach (var animation in instance.GetComponentsInChildren<Animation>())
            {
                string normal = null, fast = null;
                foreach (AnimationState state in animation)
                {
                    state.wrapMode = WrapMode.Loop;
                    if (state.name.IndexOf("Swimming_Normal", StringComparison.OrdinalIgnoreCase) >= 0) normal = state.name;
                    if (state.name.IndexOf("Swimming_Fast", StringComparison.OrdinalIgnoreCase) >= 0) fast = state.name;
                }
                if (normal == null) continue;
                animation.Play(normal);
                animation[normal].time = UnityEngine.Random.value * animation[normal].length;
                visual.swimmers.Add((animation, normal, fast ?? normal));
            }
            return instance.transform;
        }

        static void ApplyWildColor(GameObject instance, string species)
        {
            nextWildColor.TryGetValue(species, out int sequence);
            nextWildColor[species] = sequence + 1;
            int variant = sequence % WildHueOffsets.Length;
            if (variant == 0) return;

            var block = new MaterialPropertyBlock();
            foreach (var renderer in instance.GetComponentsInChildren<Renderer>(true))
            {
                var materials = renderer.sharedMaterials;
                for (int index = 0; index < materials.Length; index++)
                {
                    Material material = materials[index];
                    if (material == null || !material.HasProperty("_Color")) continue;
                    string part = material.name.ToLowerInvariant();
                    if (part.Contains("eye") || part.Contains("iris") || part.Contains("pupil") ||
                        part.Contains("mouth") || part.Contains("teeth") || part.Contains("ivory") ||
                        part.Contains("catchlight") || part.Contains("outline") || part.Contains("black") ||
                        part.Contains("belly")) continue;

                    Color original = material.color;
                    Color.RGBToHSV(original, out float hue, out float saturation, out float value);
                    bool body = part.Contains("main") || part.Contains("body") || part.Contains("scale") ||
                        part.Contains("skin") || part.Contains("face") || part.Contains("fin");
                    if (saturation < .12f && !body) continue;
                    hue = Mathf.Repeat(hue + WildHueOffsets[variant], 1f);
                    saturation = saturation < .12f ? .48f : Mathf.Clamp(saturation * 1.08f, .32f, .88f);
                    value = Mathf.Clamp(value * (variant % 2 == 0 ? 1.08f : .94f), .28f, 1f);
                    Color tint = Color.HSVToRGB(hue, saturation, value);
                    tint.a = original.a;
                    renderer.GetPropertyBlock(block, index);
                    block.SetColor("_Color", tint);
                    renderer.SetPropertyBlock(block, index);
                    block.Clear();
                }
            }
        }

        public static float ProjectedBodyArea(Vector3 size)
        {
            // Average the gameplay camera's view over a full turn. The ellipsoid
            // model accounts for width AND height without stretching the species.
            Vector3 r = size * .5f;
            if (Mathf.Min(r.x, r.y, r.z) < .001f) return 1.05f;
            float area = 0;
            Vector3 view = new Vector3(0, 16, 17).normalized;
            for (int i = 0; i < 24; i++)
            {
                Vector3 n = Quaternion.Euler(0, i * 15, 0) * view;
                area += Mathf.PI * r.x * r.y * r.z *
                    new Vector3(n.x / r.x, n.y / r.y, n.z / r.z).magnitude;
            }
            return area / 24;
        }

        public static Bounds MeasureBody(GameObject instance)
        {
            var points = new List<Vector3>();
            foreach (var skin in instance.GetComponentsInChildren<SkinnedMeshRenderer>())
            {
                var mesh = skin.sharedMesh; var vertices = mesh.vertices; var weights = mesh.boneWeights;
                for (int i = 0; i < vertices.Length && i < weights.Length; i++)
                {
                    var w = weights[i];
                    string bone = skin.bones[w.boneIndex0].name;
                    if (w.weight0 < .6f || (bone != "Main1" && bone != "Main2")) continue;
                    points.Add(instance.transform.InverseTransformPoint(skin.transform.TransformPoint(vertices[i])));
                }
            }
            if (points.Count == 0)
                foreach (var filter in instance.GetComponentsInChildren<MeshFilter>())
                {
                    var renderer = filter.GetComponent<MeshRenderer>();
                    if (renderer == null) continue;
                    var mesh = filter.sharedMesh; var vertices = mesh.vertices;
                    for (int sub = 0; sub < mesh.subMeshCount && sub < renderer.sharedMaterials.Length; sub++)
                    {
                        string material = renderer.sharedMaterials[sub].name;
                        if (!material.Contains("Painted body") && !material.Contains("Golden scales") && !material.Contains("Iridescent blue skin")) continue;
                        foreach (int i in mesh.GetTriangles(sub))
                            points.Add(instance.transform.InverseTransformPoint(filter.transform.TransformPoint(vertices[i])));
                    }
                }
            if (points.Count == 0) return new Bounds(Vector3.zero, new Vector3(1, 1, 1.8f));
            // Trim lateral outliers from pectoral/dorsal fins; retain the trunk's
            // front/back extent. Tail bones and separate fin materials are excluded.
            var x = new List<float>(); var y = new List<float>(); var z = new List<float>();
            foreach (var point in points) { x.Add(point.x); y.Add(point.y); z.Add(point.z); }
            x.Sort(); y.Sort(); z.Sort();
            int lo = Mathf.FloorToInt((points.Count - 1) * .05f), hi = points.Count - 1 - lo;
            var bounds = new Bounds();
            bounds.SetMinMax(new Vector3(x[lo], y[lo], z[0]), new Vector3(x[hi], y[hi], z[^1]));
            return bounds;
        }

        public void UpdateSwimming(bool fast)
        {
            if (fast == fastSwimming) return;
            fastSwimming = fast;
            if (referenceMotion != null) referenceMotion.SetFast(fast);
            foreach (var swimmer in swimmers)
                swimmer.animation.CrossFade(fast ? swimmer.fast : swimmer.normal, .18f);
        }
    }
}
