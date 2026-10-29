using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

namespace Chinsekid.FishGame.Editor
{
    static class OpenSeaAssetPreview
    {
        [MenuItem("Chinsekid/Fish Game/Render Downloaded Fish Preview")]
        public static void Render()
        {
            var scene = EditorSceneManager.NewPreviewScene();
            var previous = RenderSettings.ambientLight;
            RenderTexture target = null;
            Texture2D pixels = null;
            try
            {
                RenderSettings.ambientLight = new Color(.65f, .72f, .82f);
                var cameraObject = new GameObject("Asset preview camera");
                UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject, scene);
                var camera = cameraObject.AddComponent<Camera>();
                camera.scene = scene;
                camera.clearFlags = CameraClearFlags.SolidColor;
                camera.backgroundColor = new Color(.035f, .12f, .20f);
                camera.orthographic = true;
                camera.orthographicSize = 5.6f;
                camera.transform.position = new Vector3(0, 0, -20);
                var lightObject = new GameObject("Soft key light");
                UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lightObject, scene);
                var light = lightObject.AddComponent<Light>();
                light.type = LightType.Directional;
                light.intensity = 1.3f;
                light.transform.rotation = Quaternion.Euler(35, -35, 0);
                for (int i = 0; i < OpenSeaAssetSetup.FishNames.Length; i++)
                {
                    string name = OpenSeaAssetSetup.FishNames[i];
                    var source = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Resources/OpenSea/Fish/" + name + ".prefab");
                    var model = Object.Instantiate(source);
                    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(model, scene);
                    model.transform.position = new Vector3((i % 4 - 1.5f) * 4f, (1 - i / 4) * 3.5f + .3f, 0);
                    model.transform.rotation = Quaternion.Euler(12, 65, 0);
                    foreach (var animation in model.GetComponentsInChildren<Animation>())
                        if (animation.clip != null) animation.clip.SampleAnimation(animation.gameObject, .2f);
                    foreach (var renderer in model.GetComponentsInChildren<Renderer>())
                        Debug.Log("[OpenSeaPreview] " + name + " " + renderer.name + " scale=" + renderer.transform.lossyScale + " bounds=" + renderer.bounds);
                    var labelObject = new GameObject(name);
                    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(labelObject, scene);
                    labelObject.transform.position = model.transform.position + new Vector3(0, -1.25f, -2);
                    var label = labelObject.AddComponent<TextMesh>();
                    label.text = name;
                    label.anchor = TextAnchor.MiddleCenter;
                    label.characterSize = .10f;
                    label.fontSize = 42;
                    label.color = Color.white;
                }
                target = new RenderTexture(1600, 1100, 24);
                camera.targetTexture = target;
                camera.Render();
                var active = RenderTexture.active;
                RenderTexture.active = target;
                pixels = new Texture2D(1600, 1100, TextureFormat.RGB24, false);
                pixels.ReadPixels(new Rect(0, 0, 1600, 1100), 0, 0);
                pixels.Apply();
                RenderTexture.active = active;
                File.WriteAllBytes("/tmp/chinsekid-open-sea-preview.png", pixels.EncodeToPNG());
                Debug.Log("[OpenSea] Preview saved to /tmp/chinsekid-open-sea-preview.png");
            }
            finally
            {
                RenderSettings.ambientLight = previous;
                if (target != null) Object.DestroyImmediate(target);
                if (pixels != null) Object.DestroyImmediate(pixels);
                EditorSceneManager.ClosePreviewScene(scene);
            }
        }
    }
}
