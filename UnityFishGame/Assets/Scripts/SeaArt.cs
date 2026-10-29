using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Chinsekid.FishGame
{
    // Shared meshes and painted textures keep the procedural scene inexpensive.
    // UV.x follows each animal from tail to nose; UV.y wraps around its body.
    static class SeaArt
    {
        static readonly Dictionary<string, Mesh> meshes = new();
        static readonly Dictionary<string, Material> materials = new();

        public static Material Solid(Color color, float gloss)
        {
            string key = "solid" + ColorUtility.ToHtmlStringRGB(color) + ":" + gloss;
            if (materials.TryGetValue(key, out var cached) && cached != null) return cached;
            var material = new Material(Resources.Load<Material>("FishSurface")) { color = color };
            material.SetFloat("_Glossiness", gloss);
            material.SetFloat("_Metallic", 0);
            return materials[key] = material;
        }

        public static Mesh Pearl()
        {
            if (meshes.TryGetValue("pearl", out var cached) && cached != null) return cached;
            const int rings = 10, sides = 14;
            var vertices = new Vector3[(rings + 1) * (sides + 1)];
            var uv = new Vector2[vertices.Length];
            var triangles = new List<int>();
            for (int i = 0; i <= rings; i++)
                for (int j = 0; j <= sides; j++)
                {
                    float latitude = i / (float)rings * Mathf.PI;
                    float longitude = j / (float)sides * Mathf.PI * 2;
                    int index = i * (sides + 1) + j;
                    vertices[index] = new Vector3(Mathf.Sin(latitude) * Mathf.Cos(longitude), Mathf.Cos(latitude), Mathf.Sin(latitude) * Mathf.Sin(longitude)) * .5f;
                    uv[index] = new Vector2(j / (float)sides, i / (float)rings);
                    if (i < rings && j < sides) Quad(triangles, index, index + 1, index + sides + 1, index + sides + 2);
                }
            var mesh = MeshFrom("Smooth detail sphere", vertices, uv, triangles);
            var normals = new Vector3[vertices.Length];
            for (int i = 0; i < vertices.Length; i++) normals[i] = vertices[i].normalized;
            mesh.normals = normals;
            return meshes["pearl"] = mesh;
        }

        // Merge static details by material; animated joints remain separate.
        public static void CombineDetails(Transform root)
        {
            var groups = new Dictionary<Material, List<CombineInstance>>();
            var children = new List<GameObject>();
            foreach (Transform child in root)
            {
                if (child.name == "Pectoral fin" || child.name == "Tentacle") continue;
                var filter = child.GetComponent<MeshFilter>();
                var renderer = child.GetComponent<MeshRenderer>();
                if (filter == null || renderer == null) continue;
                var material = renderer.sharedMaterial;
                if (!groups.TryGetValue(material, out var group)) groups[material] = group = new List<CombineInstance>();
                group.Add(new CombineInstance { mesh = filter.sharedMesh, transform = root.worldToLocalMatrix * child.localToWorldMatrix });
                renderer.enabled = false;
                children.Add(child.gameObject);
            }
            foreach (var group in groups)
            {
                var mesh = new Mesh { name = "Merged creature details" };
                mesh.CombineMeshes(group.Value.ToArray(), true, true);
                // This instance-specific mesh is released with its owning actor.
                var part = Part("Batched details", root, mesh, group.Key, Vector3.zero, Vector3.one);
                part.AddComponent<SeaArtOwnedMesh>();
            }
            foreach (var child in children) Object.Destroy(child);
        }

        public static GameObject Part(string name, Transform parent, Mesh mesh, Material material,
            Vector3 position, Vector3 scale)
        {
            var part = new GameObject(name, typeof(MeshFilter), typeof(MeshRenderer));
            part.transform.SetParent(parent, false);
            part.transform.localPosition = position;
            part.transform.localScale = scale;
            part.GetComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = part.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            return part;
        }

        public static Material Painted(Color color, int pattern, bool fin = false)
        {
            string key = ColorUtility.ToHtmlStringRGB(color) + ":" + pattern + ":" + fin;
            if (materials.TryGetValue(key, out var existing) && existing != null) return existing;
            const int width = 128, height = 64;
            var texture = new Texture2D(width, height, TextureFormat.RGBA32, true) { name = "Painted sea creature", wrapMode = TextureWrapMode.Clamp };
            var pixels = new Color[width * height];
            Color cream = new Color(1f, .94f, .77f);
            Color back = Color.Lerp(color, new Color(.035f, .16f, .24f), .27f);
            for (int y = 0; y < height; y++)
                for (int x = 0; x < width; x++)
                {
                    float u = x / (float)(width - 1), v = y / (float)(height - 1);
                    float top = Mathf.Sin(v * Mathf.PI * 2f);
                    Color paint = Color.Lerp(color, back, Mathf.Clamp01(top) * .65f);
                    paint = Color.Lerp(paint, cream, Mathf.SmoothStep(.25f, .9f, -top) * .8f);
                    if (fin)
                    {
                        float ray = Mathf.Pow(.5f + .5f * Mathf.Cos(v * Mathf.PI * 20f), 12f);
                        paint = Color.Lerp(color, cream, .18f + ray * .30f + u * .20f);
                    }
                    else
                    {
                        float band = 0f;
                        if (pattern == 0)
                        {
                            // Broad cream bands with dark edging, painted onto the mesh.
                            float wave = u + .018f * Mathf.Cos(v * Mathf.PI * 4f);
                            float distance = Mathf.Min(Mathf.Abs(wave - .34f), Mathf.Min(Mathf.Abs(wave - .58f), Mathf.Abs(wave - .79f)));
                            paint = Color.Lerp(paint, back * .7f, 1f - Mathf.SmoothStep(.052f, .066f, distance));
                            band = 1f - Mathf.SmoothStep(.036f, .048f, distance);
                        }
                        else if (pattern == 1)
                            band = Mathf.Pow(.5f + .5f * Mathf.Sin(u * 28f + v * 3f), 16f) * .55f;
                        else
                        {
                            float spotX = Mathf.Repeat(u * 9f, 1f) - .5f;
                            float spotY = Mathf.Repeat(v * 7f + Mathf.Floor(u * 9f) * .5f, 1f) - .5f;
                            band = (1f - Mathf.SmoothStep(.12f, .25f, new Vector2(spotX, spotY).magnitude)) * .6f;
                        }
                        paint = Color.Lerp(paint, cream, band);
                        // Fine overlapping scale highlights, deliberately subtle.
                        float scales = Mathf.Pow(.5f + .5f * Mathf.Cos(u * 140f + Mathf.Sin(v * 90f)), 18f);
                        paint = Color.Lerp(paint, Color.white, scales * .065f);
                    }
                    pixels[y * width + x] = paint;
                }
            texture.SetPixels(pixels);
            texture.Apply(true, true);
            var material = new Material(Resources.Load<Material>("FishSurface")) { name = key, color = Color.white, mainTexture = texture };
            material.SetFloat("_Glossiness", fin ? .30f : .48f);
            material.SetFloat("_Metallic", .02f);
            materials[key] = material;
            return material;
        }

        public static Mesh FishBody()
        {
            if (meshes.TryGetValue("fish", out var cached) && cached != null) return cached;
            const int rings = 28, sides = 24;
            var vertices = new Vector3[(rings + 1) * (sides + 1)];
            var uv = new Vector2[vertices.Length];
            var triangles = new List<int>();
            for (int i = 0; i <= rings; i++)
            {
                float t = i / (float)rings;
                float envelope = Mathf.Pow(Mathf.Max(0, Mathf.Sin(t * Mathf.PI)), .72f);
                // Narrow tail peduncle, broad shoulders, rounded nose.
                float width = envelope * Mathf.Lerp(.24f, .69f, Mathf.SmoothStep(0, .6f, t));
                float height = envelope * Mathf.Lerp(.12f, .43f, Mathf.SmoothStep(0, .62f, t));
                for (int j = 0; j <= sides; j++)
                {
                    float angle = j / (float)sides * Mathf.PI * 2;
                    int index = i * (sides + 1) + j;
                    vertices[index] = new Vector3(Mathf.Cos(angle) * width, Mathf.Sin(angle) * height, Mathf.Lerp(-1.05f, 1.02f, t));
                    uv[index] = new Vector2(t, j / (float)sides);
                    if (i < rings && j < sides) Quad(triangles, index, index + 1, index + sides + 1, index + sides + 2);
                }
            }
            var mesh = MeshFrom("Sculpted fish body", vertices, uv, triangles);
            var normals = mesh.normals;
            for (int i = 0; i <= rings; i++)
            {
                int first = i * (sides + 1), last = first + sides;
                Vector3 normal = (normals[first] + normals[last]).normalized;
                normals[first] = normals[last] = normal;
            }
            for (int j = 0; j <= sides; j++)
            {
                normals[j] = Vector3.back;
                normals[rings * (sides + 1) + j] = Vector3.forward;
            }
            mesh.normals = normals;
            return meshes["fish"] = mesh;
        }

        // A closed, curved ribbon with a scalloped edge, rather than a flattened ball.
        public static Mesh Fin(bool tail)
        {
            string key = tail ? "tail" : "fin";
            if (meshes.TryGetValue(key, out var cached) && cached != null) return cached;
            const int rows = 8, columns = 20;
            int layer = (rows + 1) * (columns + 1);
            var vertices = new Vector3[layer * 2];
            var uv = new Vector2[vertices.Length];
            var triangles = new List<int>();
            for (int side = 0; side < 2; side++)
                for (int i = 0; i <= rows; i++)
                    for (int j = 0; j <= columns; j++)
                    {
                        float t = i / (float)rows, s = j / (float)columns;
                        float spread = tail ? Mathf.Lerp(.09f, .76f, t) : Mathf.Sin(t * Mathf.PI * .92f) * .4f;
                        float edge = tail ? .82f + .16f * Mathf.Abs(s * 2f - 1f) : 1f;
                        int index = side * layer + i * (columns + 1) + j;
                        vertices[index] = new Vector3((s * 2f - 1f) * spread,
                            Mathf.Sin(t * Mathf.PI) * .09f + (side == 0 ? .012f : -.012f) * Mathf.Sin(t * Mathf.PI), -t * edge);
                        uv[index] = new Vector2(t, s);
                        if (i < rows && j < columns)
                        {
                            int b = index + columns + 1;
                            if (side == 0) Quad(triangles, index, index + 1, b, b + 1);
                            else Quad(triangles, index, b, index + 1, b + 1);
                        }
                    }
            // Seal the two side edges; the root and outer tip meet at zero thickness.
            for (int i = 0; i < rows; i++)
            {
                int a = i * (columns + 1), b = a + columns + 1;
                Quad(triangles, a, b, a + layer, b + layer);
                Quad(triangles, a + columns, a + columns + layer, b + columns, b + columns + layer);
            }
            return meshes[key] = MeshFrom(key, vertices, uv, triangles);
        }

        public static Mesh Tube(Vector3[] points, float startRadius, float endRadius, string name)
        {
            const int sides = 8;
            int count = points.Length;
            var vertices = new Vector3[count * (sides + 1)];
            var uv = new Vector2[vertices.Length];
            var triangles = new List<int>();
            for (int i = 0; i < count; i++)
            {
                float t = i / (float)(count - 1);
                Vector3 forward = (points[Mathf.Min(i + 1, count - 1)] - points[Mathf.Max(0, i - 1)]).normalized;
                Vector3 right = Vector3.Cross(forward, Mathf.Abs(forward.y) > .95f ? Vector3.forward : Vector3.up).normalized;
                Vector3 up = Vector3.Cross(right, forward).normalized;
                float radius = Mathf.Lerp(startRadius, endRadius, t);
                for (int j = 0; j <= sides; j++)
                {
                    float angle = j / (float)sides * Mathf.PI * 2;
                    int index = i * (sides + 1) + j;
                    vertices[index] = points[i] + (right * Mathf.Cos(angle) + up * Mathf.Sin(angle)) * radius;
                    uv[index] = new Vector2(t, j / (float)sides);
                    if (i < count - 1 && j < sides) Quad(triangles, index, index + sides + 1, index + 1, index + sides + 2);
                }
            }
            // End caps have separate vertices so their normals remain flat.
            var allVertices = new List<Vector3>(vertices);
            var allUV = new List<Vector2>(uv);
            for (int end = 0; end < 2; end++)
            {
                int ring = end == 0 ? 0 : count - 1;
                int center = allVertices.Count;
                allVertices.Add(points[ring]); allUV.Add(new Vector2(end, .5f));
                int start = allVertices.Count;
                for (int j = 0; j <= sides; j++)
                {
                    allVertices.Add(vertices[ring * (sides + 1) + j]);
                    allUV.Add(new Vector2(end, j / (float)sides));
                }
                for (int j = 0; j < sides; j++)
                {
                    triangles.Add(center);
                    triangles.Add(start + (end == 0 ? j : j + 1));
                    triangles.Add(start + (end == 0 ? j + 1 : j));
                }
            }
            return MeshFrom(name, allVertices.ToArray(), allUV.ToArray(), triangles);
        }

        public static Mesh Coral(int variant)
        {
            string key = "coral" + variant;
            if (meshes.TryGetValue(key, out var cached) && cached != null) return cached;
            var branches = new List<CombineInstance>();
            for (int i = 0; i < 7; i++)
            {
                float angle = i * 2.39996f + variant;
                float length = .65f + Mathf.Abs(Mathf.Sin(i * 7.1f + variant)) * .75f;
                Vector3 direction = new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle));
                var points = new Vector3[9];
                for (int j = 0; j < points.Length; j++)
                {
                    float t = j / 8f;
                    points[j] = direction * (t * t * .6f) + Vector3.up * (t * length);
                }
                branches.Add(new CombineInstance { mesh = Tube(points, .11f, .035f, "Coral branch"), transform = Matrix4x4.identity });
                for (int fork = 0; fork < 2; fork++)
                {
                    Vector3 root = points[4 + fork];
                    Vector3 outward = Quaternion.Euler(0, fork == 0 ? -42 : 42, 0) * direction;
                    var forkPoints = new Vector3[6];
                    for (int j = 0; j < 6; j++) forkPoints[j] = root + outward * (j / 5f * .32f) + Vector3.up * (j / 5f * .44f);
                    branches.Add(new CombineInstance { mesh = Tube(forkPoints, .065f, .018f, "Coral tip"), transform = Matrix4x4.identity });
                }
            }
            var mesh = new Mesh { name = "Branching coral colony" };
            mesh.CombineMeshes(branches.ToArray(), true, true);
            foreach (var branch in branches) Object.Destroy(branch.mesh);
            return meshes[key] = mesh;
        }

        public static Mesh Arm(int index)
        {
            string key = "arm" + index;
            if (meshes.TryGetValue(key, out var cached) && cached != null) return cached;
            var points = new Vector3[16];
            for (int j = 0; j < points.Length; j++)
            {
                float t = j / 15f;
                points[j] = new Vector3(Mathf.Sin(t * 4.5f + index * .4f) * .14f * t,
                    -.1f - Mathf.Sin(t * Mathf.PI) * .16f + t * t * .20f, -t * .92f);
            }
            return meshes[key] = Tube(points, .13f, .012f, "Curled octopus arm");
        }

        public static Mesh Feeler()
        {
            if (meshes.TryGetValue("feeler", out var cached) && cached != null) return cached;
            var points = new Vector3[12];
            for (int j = 0; j < points.Length; j++)
            {
                float t = j / 11f;
                points[j] = new Vector3(t * .3f, Mathf.Sin(t * Mathf.PI) * .14f, t * .95f);
            }
            return meshes["feeler"] = Tube(points, .025f, .006f, "Swept shrimp antenna");
        }

        public static Material Sand()
        {
            if (materials.TryGetValue("sand", out var cached) && cached != null) return cached;
            const int size = 256;
            var texture = new Texture2D(size, size, TextureFormat.RGBA32, true) { name = "Sand ripples and light", wrapMode = TextureWrapMode.Repeat };
            var pixels = new Color[size * size];
            for (int y = 0; y < size; y++)
                for (int x = 0; x < size; x++)
                {
                    float u = x / (float)size, v = y / (float)size;
                    float ripples = .5f + .5f * Mathf.Sin((v * 14f + Mathf.Sin(u * Mathf.PI * 2f) * .28f) * Mathf.PI * 2f);
                    float light = Mathf.Pow(.5f + .5f * Mathf.Sin(u * Mathf.PI * 8f + Mathf.Sin(v * Mathf.PI * 6f)), 14f)
                        * Mathf.Pow(.5f + .5f * Mathf.Cos(v * Mathf.PI * 8f - Mathf.Cos(u * Mathf.PI * 4f)), 4f);
                    pixels[y * size + x] = Color.Lerp(new Color(.19f, .48f, .52f), new Color(.54f, .72f, .64f), ripples * .16f + light * .42f);
                }
            texture.SetPixels(pixels); texture.Apply(true, true);
            var material = new Material(Resources.Load<Material>("FishSurface")) { name = "Shallow sand", mainTexture = texture };
            material.mainTextureScale = new Vector2(12, 10);
            material.SetFloat("_Glossiness", .08f);
            return materials["sand"] = material;
        }

        static void Quad(List<int> triangles, int a, int b, int c, int d)
        {
            triangles.Add(a); triangles.Add(b); triangles.Add(c);
            triangles.Add(c); triangles.Add(b); triangles.Add(d);
        }

        static Mesh MeshFrom(string name, Vector3[] vertices, Vector2[] uv, List<int> triangles)
        {
            var mesh = new Mesh { name = name, vertices = vertices, uv = uv, triangles = triangles.ToArray() };
            mesh.RecalculateNormals();
            mesh.RecalculateTangents();
            mesh.RecalculateBounds();
            return mesh;
        }
    }

    sealed class SeaArtOwnedMesh : MonoBehaviour
    {
        void OnDestroy()
        {
            var filter = GetComponent<MeshFilter>();
            if (filter != null && filter.sharedMesh != null) Destroy(filter.sharedMesh);
        }
    }
}
