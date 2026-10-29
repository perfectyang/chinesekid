using System.Collections.Generic;
using UnityEngine;

namespace Chinsekid.FishGame
{
    // Reuse a finite set of surfaces and reef colonies around an unbounded player.
    public sealed class EndlessSeaWorld : MonoBehaviour
    {
        Transform floor;
        Transform caustics;
        Transform bubbles;
        readonly List<Transform> gardens = new();

        public void Initialize(Transform parent, Transform seabed, Transform bubbleEmitter)
        {
            floor = seabed;
            bubbles = bubbleEmitter;
            foreach (Transform child in parent)
            {
                if (child.name == "Colorful reef garden") gardens.Add(child);
                if (child.name == "Moving underwater caustics") caustics = child;
            }
            // Larger than the camera's entire far clip footprint. Recenter in
            // texture-repeat multiples so the sand never visibly slides.
            floor.localScale = new Vector3(80, 1, 80);
            var material = floor.GetComponent<Renderer>().sharedMaterial;
            material.mainTextureScale = new Vector2(80, 80);
            if (material.HasProperty("_BumpMap")) material.SetTextureScale("_BumpMap", new Vector2(80, 80));
            if (caustics != null) caustics.localScale = new Vector3(80, 1, 80);
        }

        public void Follow(Vector3 playerPosition)
        {
            float x = Mathf.Round(playerPosition.x / 80) * 80;
            float z = Mathf.Round(playerPosition.z / 80) * 80;
            floor.position = new Vector3(x, -1.25f, z);
            if (caustics != null) caustics.position = new Vector3(x, -1.19f, z);
            if (bubbles != null) bubbles.position = new Vector3(playerPosition.x, .2f, playerPosition.z);
            foreach (var garden in gardens)
            {
                var p = garden.position;
                p.x = playerPosition.x + Mathf.Repeat(p.x - playerPosition.x + 58.5f, 117f) - 58.5f;
                p.z = playerPosition.z + Mathf.Repeat(p.z - playerPosition.z + 49.5f, 99f) - 49.5f;
                garden.position = p;
            }
        }

        public void ShiftOrigin(Vector3 offset)
        {
            foreach (var garden in gardens) garden.position -= offset;
        }
    }
}
