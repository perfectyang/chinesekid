using System.Collections.Generic;
using UnityEngine;

namespace Chinsekid.FishGame
{
    // A small stylized steak based on the red cut, pale marbling and green garnish.
    public sealed class MeatPickup : MonoBehaviour
    {
        public const int ScoreValue = 18;
        public const float Lifetime = 19f;
        const float VisualScale = .56f;

        static Mesh steakMesh;
        static Material topMaterial;
        static Material sideMaterial;
        static Material fatMaterial;
        static Material leafMaterial;
        static Material highlightMaterial;

        Vector3 landingPosition;
        Vector3 launchPosition;
        Transform visual;
        float age;

        public float Age => age;

        public void Initialize(Vector3 from, Vector3 landing)
        {
            EnsureSharedArt();
            launchPosition = new Vector3(from.x, .36f, from.z);
            landingPosition = new Vector3(landing.x, .22f, landing.z);
            transform.position = launchPosition;

            visual = new GameObject("Steak model").transform;
            visual.SetParent(transform, false);
            visual.localScale = Vector3.one * VisualScale;
            var body = SeaArt.Part("Rounded red steak", visual, steakMesh, topMaterial, Vector3.zero, Vector3.one);
            body.GetComponent<MeshRenderer>().sharedMaterials = new[] { topMaterial, sideMaterial };

            AddMarbling(new[] {
                new Vector3(-.57f, .21f, -.12f), new Vector3(-.32f, .21f, -.22f),
                new Vector3(-.05f, .21f, -.17f), new Vector3(.17f, .21f, -.05f),
                new Vector3(.51f, .21f, -.10f)
            }, .037f);
            AddMarbling(new[] {
                new Vector3(-.20f, .21f, .35f), new Vector3(-.04f, .21f, .18f),
                new Vector3(.22f, .21f, .13f), new Vector3(.44f, .21f, .24f)
            }, .028f);

            // Soft ruby patches make the top read as a cut of meat from above.
            SeaArt.Part("Meat highlight", visual, SeaArt.Pearl(), highlightMaterial,
                new Vector3(-.31f, .202f, .10f), new Vector3(.44f, .015f, .22f));
            SeaArt.Part("Second meat highlight", visual, SeaArt.Pearl(), highlightMaterial,
                new Vector3(.22f, .202f, -.23f), new Vector3(.29f, .015f, .15f));

            for (int i = 0; i < 7; i++)
            {
                float spread = i - 3f;
                var leaf = SeaArt.Part("Green garnish leaf", visual, SeaArt.Pearl(), leafMaterial,
                    new Vector3(.19f + spread * .11f, .19f, .48f + Mathf.Abs(spread) * .018f),
                    new Vector3(.25f, .70f + (i % 2) * .14f, .12f));
                leaf.transform.localRotation = Quaternion.Euler(-28f, spread * 14f, spread * -13f);
            }
        }

        public void Tick(float dt)
        {
            age += dt;
            float landing = Mathf.Clamp01(age / .65f);
            float eased = 1f - Mathf.Pow(1f - landing, 3f);
            transform.position = Vector3.Lerp(launchPosition, landingPosition, eased) +
                Vector3.up * (Mathf.Sin(landing * Mathf.PI) * .42f + Mathf.Sin(age * 2.8f) * .035f);
            visual.localRotation = Quaternion.Euler(0f, age * 38f, Mathf.Sin(age * 3f) * 5f);
            float appear = Mathf.Clamp01(age / .18f);
            float fade = Mathf.Clamp01((Lifetime - age) / 1.5f);
            float pop = 1f + Mathf.Sin(appear * Mathf.PI) * .22f;
            visual.localScale = Vector3.one * (VisualScale * appear * pop * fade);
        }

        public void ShiftOrigin(Vector3 offset)
        {
            transform.position -= offset;
            launchPosition -= offset;
            landingPosition -= offset;
        }

        void AddMarbling(Vector3[] points, float width)
        {
            var line = new GameObject("Cream fat marbling", typeof(LineRenderer)).GetComponent<LineRenderer>();
            line.transform.SetParent(visual, false);
            line.sharedMaterial = fatMaterial;
            line.useWorldSpace = false;
            line.numCapVertices = 5;
            line.numCornerVertices = 5;
            line.startWidth = line.endWidth = width;
            line.positionCount = points.Length;
            line.SetPositions(points);
            line.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            line.receiveShadows = false;
        }

        static void EnsureSharedArt()
        {
            if (steakMesh != null) return;
            topMaterial = SeaArt.Solid(new Color(.53f, .08f, .11f), .42f);
            sideMaterial = SeaArt.Solid(new Color(.32f, .04f, .065f), .27f);
            fatMaterial = SeaArt.Solid(new Color(1f, .83f, .76f), .45f);
            leafMaterial = SeaArt.Solid(new Color(.08f, .29f, .09f), .25f);
            highlightMaterial = SeaArt.Solid(new Color(.66f, .13f, .17f), .43f);

            var outline = new[] {
                new Vector2(-.77f, -.08f), new Vector2(-.68f, -.37f), new Vector2(-.39f, -.55f),
                new Vector2(-.08f, -.53f), new Vector2(.17f, -.43f), new Vector2(.53f, -.42f),
                new Vector2(.76f, -.22f), new Vector2(.82f, .05f), new Vector2(.70f, .31f),
                new Vector2(.43f, .49f), new Vector2(.15f, .50f), new Vector2(-.13f, .42f),
                new Vector2(-.38f, .47f), new Vector2(-.64f, .29f)
            };
            int count = outline.Length;
            var vertices = new Vector3[count * 3 + 1];
            vertices[0] = new Vector3(0, .19f, 0);
            for (int i = 0; i < count; i++)
            {
                Vector2 point = outline[i];
                vertices[1 + i] = new Vector3(point.x * .90f, .19f, point.y * .90f);
                vertices[1 + count + i] = new Vector3(point.x, .09f, point.y);
                vertices[1 + count * 2 + i] = new Vector3(point.x * .91f, -.15f, point.y * .91f);
            }
            var top = new List<int>();
            var side = new List<int>();
            for (int i = 0; i < count; i++)
            {
                int next = (i + 1) % count;
                top.Add(0); top.Add(1 + next); top.Add(1 + i);
                for (int ring = 0; ring < 2; ring++)
                {
                    int a = 1 + ring * count + i;
                    int b = 1 + ring * count + next;
                    int c = a + count;
                    int d = b + count;
                    side.Add(a); side.Add(b); side.Add(c);
                    side.Add(b); side.Add(d); side.Add(c);
                }
            }
            steakMesh = new Mesh { name = "Beveled steak cut" };
            steakMesh.vertices = vertices;
            steakMesh.subMeshCount = 2;
            steakMesh.SetTriangles(top, 0);
            steakMesh.SetTriangles(side, 1);
            steakMesh.RecalculateNormals();

        }
    }
}
