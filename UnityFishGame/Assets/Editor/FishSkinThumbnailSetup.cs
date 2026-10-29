using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Chinsekid.FishGame.Editor
{
    public static class FishSkinThumbnailSetup
    {
        static readonly string[] Models = {
            "Clownfish", "BlueTang", "ButterflyFish", "CoralGrouper", "Goldfish", "Koi", "Puffer", "RoyalGramma", "Tang", "Shark", "Anglerfish", "Lionfish",
            "GoldenReference", "PatternedReef", "RubyLionfish", "SpottedPuffer", "AzureAngelfish", "FangHunter", "GrinningShark", "IridescentShark", "Shrimp", "Octopus"
        };
        [MenuItem("Chinsekid/Fish Game/Render Native Skin Thumbnails")]
        public static void RenderAll()
        {
            string output=Path.GetFullPath(Path.Combine(Application.dataPath,"../../chinsekid/Resources/FishModelPreviews"));Directory.CreateDirectory(output);
            foreach(string name in Models)Render(name,output);
            string sprites=Path.GetFullPath(Path.Combine(Application.dataPath,"../../chinsekid/Resources/FishSprites"));
            Directory.CreateDirectory(sprites);
            Render("IridescentShark",sprites,true);
            Debug.Log("[FishSkins] Rendered 22 native skin thumbnails from actual Unity models.");
        }
        [MenuItem("Chinsekid/Fish Game/Prepare Rounded Fish And Thumbnails")]
        public static void PrepareRoundedFishAndRender()
        {
            OpenSeaAssetSetup.Prepare();
            RenderAll();
            OpenSeaAssetPreview.Render();
            ReferenceFishCollectionSetup.RenderGallery();
        }
        static void Render(string name,string output,bool sideView=false)
        {
            var scene=EditorSceneManager.NewPreviewScene();var previous=RenderTexture.active;var target=new RenderTexture(512,384,24,RenderTextureFormat.ARGB32);Texture2D image=null;
            try
            {
                GameObject model;
                if(name=="Shrimp"||name=="Octopus")
                {
                    model=new GameObject(name);SceneManager.MoveGameObjectToScene(model,scene);
                    model.AddComponent<FishActor>().Configure(1,name=="Shrimp"?SeaCreatureKind.Shrimp:SeaCreatureKind.Octopus,name=="Shrimp"?new Color(.98f,.48f,.58f):new Color(.62f,.38f,.68f),true);
                }
                else
                {
                    var prefab=Resources.Load<GameObject>("OpenSea/Fish/"+name);
                    if(prefab==null)throw new FileNotFoundException("Missing thumbnail model: "+name);
                    model=Object.Instantiate(prefab);SceneManager.MoveGameObjectToScene(model,scene);
                }
                foreach(var animation in model.GetComponentsInChildren<Animation>())if(animation.clip!=null)animation.clip.SampleAnimation(animation.gameObject,0);
                foreach(var motion in model.GetComponentsInChildren<GoldenReferenceFishMotion>())motion.enabled=false;
                var cameraObject=new GameObject("Skin camera",typeof(Camera));SceneManager.MoveGameObjectToScene(cameraObject,scene);var camera=cameraObject.GetComponent<Camera>();camera.scene=scene;camera.targetTexture=target;camera.orthographic=true;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.clear;
                Vector3 direction=sideView?new Vector3(-6,.25f,0):new Vector3(6,1.5f,3.4f);
                camera.transform.position=direction;camera.transform.LookAt(Vector3.zero);
                var bounds=new Bounds();bool has=false;
                foreach(var mf in model.GetComponentsInChildren<MeshFilter>())foreach(var v in mf.sharedMesh.vertices)Encapsulate(ref bounds,ref has,mf.transform.TransformPoint(v));
                foreach(var skin in model.GetComponentsInChildren<SkinnedMeshRenderer>())
                {foreach(var v in skin.sharedMesh.vertices)Encapsulate(ref bounds,ref has,skin.transform.TransformPoint(v));}
                camera.transform.position=bounds.center+direction;camera.transform.LookAt(bounds.center);
                float maxX=0,maxY=0;
                for(int x=-1;x<=1;x+=2)for(int y=-1;y<=1;y+=2)for(int z=-1;z<=1;z+=2)
                {var at=bounds.center+Vector3.Scale(bounds.extents,new Vector3(x,y,z));var local=camera.transform.InverseTransformPoint(at);maxX=Mathf.Max(maxX,Mathf.Abs(local.x));maxY=Mathf.Max(maxY,Mathf.Abs(local.y));}
                camera.orthographicSize=Mathf.Max(maxY,maxX/(512f/384))*1.14f;
                var key=new GameObject("Skin key",typeof(Light));SceneManager.MoveGameObjectToScene(key,scene);key.GetComponent<Light>().type=LightType.Directional;key.GetComponent<Light>().intensity=1.10f;key.transform.rotation=camera.transform.rotation*Quaternion.Euler(25,-30,0);
                var fill=new GameObject("Skin fill",typeof(Light));SceneManager.MoveGameObjectToScene(fill,scene);fill.GetComponent<Light>().type=LightType.Directional;fill.GetComponent<Light>().intensity=.65f;fill.transform.rotation=camera.transform.rotation*Quaternion.Euler(-20,130,0);
                camera.Render();RenderTexture.active=target;image=new Texture2D(512,384,TextureFormat.RGBA32,false);image.ReadPixels(new Rect(0,0,512,384),0,0);image.Apply();File.WriteAllBytes(Path.Combine(output,(sideView?"fish_iridescent_shark":name)+".png"),image.EncodeToPNG());
            }
            finally{RenderTexture.active=previous;if(image!=null)Object.DestroyImmediate(image);EditorSceneManager.ClosePreviewScene(scene);Object.DestroyImmediate(target);}
        }
        static void Encapsulate(ref Bounds bounds,ref bool has,Vector3 p){if(!has){bounds=new Bounds(p,Vector3.zero);has=true;}else bounds.Encapsulate(p);}
    }
}
