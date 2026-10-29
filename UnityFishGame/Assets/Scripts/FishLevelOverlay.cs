using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace Chinsekid.FishGame
{
    // A shared screen-space canvas keeps badges upright and readable as fish turn.
    public sealed class FishLevelOverlay : MonoBehaviour
    {
        sealed class Badge
        {
            public RectTransform rect;
            public Text text;
            public int level = -1;
        }

        readonly Dictionary<FishActor, Badge> badges = new();
        readonly List<FishActor> removed = new();
        readonly List<Rect> occupied = new();
        RectTransform surface;
        Font font;

        public void Initialize()
        {
            var canvas = gameObject.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = -1; // Controls and result panels remain above fish badges.
            var scaler = gameObject.AddComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ConstantPixelSize;
            scaler.scaleFactor = 1.45f;
            surface = (RectTransform)transform;
            font = Font.CreateDynamicFontFromOSFont(new[] { "Arial", "PingFang SC" }, 30);
        }

        public void Refresh(Camera camera, FishActor player, List<FishActor> fish)
        {
            removed.Clear();
            foreach (var entry in badges)
                if (entry.Key == null)
                {
                    Destroy(entry.Value.rect.gameObject);
                    removed.Add(entry.Key);
                }
            foreach (var actor in removed) badges.Remove(actor);
            occupied.Clear();
            Place(camera, player, player);
            foreach (var actor in fish)
                if (actor != null && actor.IsHunter) Place(camera, player, actor);
            foreach (var actor in fish)
                if (actor != null && !actor.IsHunter) Place(camera, player, actor);
            if (badges.TryGetValue(player, out var playerBadge)) playerBadge.rect.SetAsLastSibling();
        }

        public void RemoveActor(FishActor actor)
        {
            if (actor == null || !badges.TryGetValue(actor, out var badge)) return;
            badges.Remove(actor);
            Destroy(badge.rect.gameObject);
        }

        void Place(Camera camera, FishActor player, FishActor actor)
        {
            var screen = camera.WorldToScreenPoint(actor.transform.position + Vector3.up * (actor.Size * .8f + .3f));
            bool visible = screen.z > 0 && screen.x > 0 && screen.x < Screen.width && screen.y > 0 && screen.y < Screen.height;
            if (!badges.TryGetValue(actor, out var badge))
            {
                if (!visible) return;
                badge = CreateBadge(actor.IsPlayer);
                badges.Add(actor, badge);
            }
            if (badge.rect.gameObject.activeSelf != visible) badge.rect.gameObject.SetActive(visible);
            if (!visible) return;
            RectTransformUtility.ScreenPointToLocalPointInRectangle(surface, screen, null, out var point);
            Vector2 origin = point + Vector2.up * 18;
            Vector2 position = origin;
            for (int step = 0; step < 4; step++)
            {
                position = origin + Vector2.up * (step * 36);
                var bounds = new Rect(position - badge.rect.sizeDelta * .5f - Vector2.one * 3, badge.rect.sizeDelta + Vector2.one * 6);
                bool overlaps = false;
                foreach (var other in occupied) if (bounds.Overlaps(other)) { overlaps = true; break; }
                if (!overlaps || step == 3) { occupied.Add(bounds); break; }
            }
            badge.rect.anchoredPosition = position;
            if (!actor.IsPlayer)
            {
                float distance = Vector3.Distance(actor.transform.position, player.transform.position);
                float far = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(3.5f, 9f, distance));
                float scale = Mathf.Lerp(1f, .84f, far);
                badge.rect.localScale = Vector3.one * scale;
                badge.text.color = new Color(.87f, .97f, 1f, Mathf.Lerp(1f, .88f, far));
            }
            if (badge.level != actor.Level)
            {
                badge.level = actor.Level;
                badge.text.text = (actor.IsPlayer ? "★ Lv." : "Lv.") + actor.Level;
            }
        }

        Badge CreateBadge(bool player)
        {
            var root = new GameObject("Fish level badge", typeof(RectTransform));
            root.transform.SetParent(transform, false);
            var rect = (RectTransform)root.transform;
            rect.sizeDelta = new Vector2(player ? 122 : 100, player ? 44 : 40);
            var label = new GameObject("Level", typeof(RectTransform), typeof(Text));
            label.transform.SetParent(root.transform, false);
            var labelRect = (RectTransform)label.transform;
            labelRect.anchorMin = Vector2.zero;
            labelRect.anchorMax = Vector2.one;
            labelRect.offsetMin = labelRect.offsetMax = Vector2.zero;
            var text = label.GetComponent<Text>();
            text.font = font;
            text.fontSize = player ? 27 : 26;
            text.fontStyle = FontStyle.Bold;
            text.alignment = TextAnchor.MiddleCenter;
            text.resizeTextForBestFit = true;
            text.resizeTextMinSize = 22;
            text.resizeTextMaxSize = text.fontSize;
            text.raycastTarget = false;
            // Warm amber identifies the player; other fish keep their deep-sea blue labels.
            text.color = player
                ? new Color(1f, .72f, .29f, 1f)
                : new Color(.87f, .97f, 1f, 1f);
            var outline = label.AddComponent<Outline>();
            outline.effectColor = new Color(.025f, .09f, .20f, 1f);
            outline.effectDistance = new Vector2(2.2f, -2.2f);
            return new Badge { rect = rect, text = text };
        }

        void OnDestroy()
        {
            if (font != null) Destroy(font);
        }
    }
}
