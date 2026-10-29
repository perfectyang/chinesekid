using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace Chinsekid.FishGame.Editor
{
    // An original mesh modeled from the supplied side-view reference, forward = +Z.
    static class GoldenReferenceFishSetup
    {
        const string Art = "Assets/Art/GoldenReferenceFish";
        const string PrefabPath = "Assets/Resources/OpenSea/Fish/GoldenReference.prefab";
        static Material gold, dark, blue, black, white, bodyPaint, finPaint;

        [MenuItem("Chinsekid/Fish Game/Create Golden Reference Fish")]
        public static void PrepareAndRender()
        {
            Directory.CreateDirectory(Art);
            Directory.CreateDirectory("Assets/Resources/OpenSea/Fish");
            AssetDatabase.Refresh();
            gold = Material("Lip gold", new Color(.95f, .48f, .065f), .38f);
            dark = Material("Warm dark outline", new Color(.16f, .085f, .038f), .28f);
            blue = Material("Blue gray iris", new Color(.25f, .58f, .71f), .66f);
            black = Material("Deep pupil", new Color(.022f, .018f, .018f), .65f);
            white = Material("Eye catchlight", new Color(1, .97f, .85f), .75f);
            bodyPaint = Material("Golden scales", Color.white, .30f);
            bodyPaint.mainTexture = Paint(false);
            finPaint = Material("Charcoal fins gold edges", Color.white, .27f);
            finPaint.mainTexture = Paint(true);
            var root = new GameObject("GoldenReference");
            try
            {
                Part(root.transform, "Continuous golden body", Body(), bodyPaint);
                Sphere(root.transform, "Rounded orange gold face", new Vector3(0,-.02f,.60f),
                    new Vector3(.86f,1.03f,1.00f), Material("Orange gold face",new Color(.96f,.55f,.09f),.32f));
                var motion = root.AddComponent<GoldenReferenceFishMotion>();
                motion.tail = new GameObject("Animated tail joint").transform;
                motion.tail.SetParent(root.transform, false);
                motion.tail.localPosition = new Vector3(0, 0, -1.05f);
                Part(motion.tail, "Forked gold-edged tail", Fin("Tail", new[] {
                    new Vector2(0,.10f), new Vector2(-.24f,.24f), new Vector2(-.77f,.72f),
                    new Vector2(-.84f,.73f), new Vector2(-.80f,.55f), new Vector2(-.62f,.10f),
                    new Vector2(-.61f,-.12f), new Vector2(-.85f,-.64f), new Vector2(-.82f,-.70f),
                    new Vector2(-.62f,-.61f), new Vector2(-.22f,-.24f), new Vector2(0,-.10f)
                }), finPaint);
                Part(root.transform, "Arched dorsal fin", Fin("Dorsal", new[] {
                    new Vector2(-.83f,.25f), new Vector2(-.68f,.48f), new Vector2(-.47f,.78f),
                    new Vector2(-.18f,.96f), new Vector2(.10f,1.01f), new Vector2(.42f,.92f),
                    new Vector2(.73f,.69f), new Vector2(.85f,.48f), new Vector2(.35f,.53f), new Vector2(-.35f,.40f)
                }), finPaint);
                Part(root.transform, "Flowing lower fin", Fin("Lower", new[] {
                    new Vector2(-.80f,-.22f), new Vector2(-.42f,-.44f), new Vector2(.05f,-.55f),
                    new Vector2(.29f,-.48f), new Vector2(.14f,-.77f), new Vector2(-.34f,-1.01f),
                    new Vector2(-.22f,-.76f), new Vector2(-.79f,-.88f), new Vector2(-.59f,-.61f)
                }), finPaint);
                for (int side = -1; side <= 1; side += 2)
                {
                    var pivot = new GameObject(side < 0 ? "Left fin joint" : "Right fin joint").transform;
                    pivot.SetParent(root.transform, false);
                    pivot.localPosition = new Vector3(side * .39f, -.05f, .17f);
                    var fin = Part(pivot, "Pectoral fin", Fin("Pectoral", new[] {
                        new Vector2(.10f,.14f), new Vector2(-.08f,.20f), new Vector2(-.40f,.09f),
                        new Vector2(-.62f,-.18f), new Vector2(-.54f,-.29f), new Vector2(-.21f,-.21f), new Vector2(.06f,-.09f)
                    }), finPaint);
                    fin.transform.localRotation = Quaternion.Euler(0, side * 32, 0);
                    if (side < 0) motion.leftFin = pivot; else motion.rightFin = pivot;
                    Vector3 eye = new Vector3(side * .335f, .235f, .67f);
                    Quaternion look = Quaternion.LookRotation(new Vector3(side * .83f, .12f, .55f));
                    var eyeRoot = new GameObject("Large blue eye").transform;
                    eyeRoot.SetParent(root.transform, false);
                    eyeRoot.localPosition = eye;
                    eyeRoot.localRotation = look;
                    Sphere(eyeRoot, "Dark eye rim", Vector3.zero, new Vector3(.40f,.43f,.16f), dark);
                    Sphere(eyeRoot, "Blue iris", new Vector3(0,0,.067f), new Vector3(.32f,.35f,.10f), blue);
                    Sphere(eyeRoot, "Black pupil", new Vector3(.016f,0,.11f), new Vector3(.16f,.18f,.055f), black);
                    Sphere(eyeRoot, "Small eye highlight", new Vector3(-.045f,.072f,.139f), new Vector3(.057f,.057f,.016f), white);
                    var points = new List<Vector3>();
                    for (int j = 0; j <= 24; j++)
                    {
                        float t = j / 24f;
                        float y = Mathf.Lerp(-.40f,.47f,t);
                        float z = .36f - .20f * Mathf.Sin(t * Mathf.PI);
                        float x = side * .435f * Mathf.Sqrt(Mathf.Max(.05f,1-y*y/.36f));
                        points.Add(new Vector3(x,y,z));
                    }
                    Part(root.transform,"Curved gill line",Tube("Gill"+side,points,.012f),dark);
                }
                Sphere(root.transform,"Dark mouth opening",new Vector3(0,-.20f,1.034f),new Vector3(.46f,.19f,.08f),dark);
                var lips = new List<Vector3>();
                for (int i=0;i<=64;i++)
                {
                    float a=i/64f*Mathf.PI*2;
                    lips.Add(new Vector3(Mathf.Cos(a)*.235f,-.20f+Mathf.Sin(a)*.104f,
                        1.075f + .025f*Mathf.Cos(a)*Mathf.Cos(a)));
                }
                Part(root.transform,"Thick sculpted golden lips",Tube("Lips",lips,.042f),gold);
                PrefabUtility.SaveAsPrefabAsset(root, PrefabPath);
                AssetDatabase.SaveAssets();
                Debug.Log("[GoldenFish] Saved original reference fish prefab with animated tail and paired fins.");
            }
            finally { Object.DestroyImmediate(root); }
            RenderViews();
        }

        static Material Material(string name, Color color, float gloss)
        {
            string path=Art+"/"+name+".mat";
            var material=AssetDatabase.LoadAssetAtPath<Material>(path);
            if(material==null) { material=new Material(Shader.Find("Standard")); AssetDatabase.CreateAsset(material,path); }
            material.color=color; material.SetFloat("_Glossiness",gloss); material.SetFloat("_Metallic",0);
            EditorUtility.SetDirty(material); return material;
        }

        static Texture2D Paint(bool fin)
        {
            const int w=512,h=256;
            var texture=new Texture2D(w,h,TextureFormat.RGBA32,false);
            for(int y=0;y<h;y++) for(int x=0;x<w;x++)
            {
                float u=x/(float)(w-1),v=y/(float)(h-1); Color c;
                if(fin)
                {
                    float rim=Smooth(.77f,.92f,v);
                    float rays=Mathf.Pow(.5f+.5f*Mathf.Cos(u*65f),12f)*.32f;
                    c=Color.Lerp(new Color(.20f,.23f,.24f),new Color(.90f,.49f,.12f),rim);
                    c=Color.Lerp(c,new Color(.095f,.075f,.05f),rays);
                }
                else
                {
                    float top=Mathf.Sin(v*Mathf.PI*2);
                    c=Color.Lerp(new Color(.94f,.64f,.14f),new Color(.62f,.37f,.065f),Mathf.Clamp01(top)*.46f);
                    c=Color.Lerp(c,new Color(1f,.85f,.39f),Mathf.Clamp01(-top)*.55f);
                    c=Color.Lerp(c,new Color(.96f,.49f,.065f),Smooth(.70f,.93f,u)*.85f);
                    float row=Mathf.Floor(v*14f);
                    float sx=Mathf.Repeat(u*16f+row*.5f,1)-.5f;
                    float sy=Mathf.Repeat(v*14f,1)-.5f;
                    float arc=Mathf.Abs(new Vector2(sx*1.3f,sy).magnitude-.43f);
                    float mark=(1-Smooth(.024f,.06f,arc))*Smooth(-.08f,.13f,sx);
                    mark*=Smooth(.10f,.22f,u)*(1-Smooth(.70f,.78f,u));
                    c=Color.Lerp(c,new Color(.45f,.30f,.07f),mark*.38f);
                }
                texture.SetPixel(x,y,c);
            }
            texture.Apply(); string path=Art+(fin?"/FinPaint.png":"/GoldenScales.png");
            File.WriteAllBytes(path,texture.EncodeToPNG()); Object.DestroyImmediate(texture);
            AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
            return AssetDatabase.LoadAssetAtPath<Texture2D>(path);
        }

        static float Smooth(float a,float b,float t) => Mathf.SmoothStep(0,1,Mathf.InverseLerp(a,b,t));

        static Mesh Body()
        {
            var vertices=new List<Vector3>();var uv=new List<Vector2>();var triangles=new List<int>();
            const int rings=48,sides=48;
            for(int i=0;i<=rings;i++)
            {
                float t=i/(float)rings;
                float fullness=Mathf.Pow(Mathf.Max(0,Mathf.Sin(t*Mathf.PI)),.68f);
                float width=fullness*Mathf.Lerp(.12f,.55f,Smooth(0,.64f,t));
                float height=fullness*Mathf.Lerp(.16f,.66f,Smooth(0,.60f,t));
                for(int j=0;j<=sides;j++)
                {
                    float a=j/(float)sides*Mathf.PI*2;
                    vertices.Add(new Vector3(Mathf.Cos(a)*width,Mathf.Sin(a)*height,Mathf.Lerp(-1.16f,1.04f,t)));
                    uv.Add(new Vector2(t,j/(float)sides));
                    if(i<rings&&j<sides) Quad(triangles,i*(sides+1)+j,i*(sides+1)+j+1,(i+1)*(sides+1)+j,(i+1)*(sides+1)+j+1);
                }
            }
            var mesh=SaveMesh("Body",vertices,uv,triangles);
            var normals=mesh.normals;
            for(int i=0;i<=rings;i++)
            {
                int first=i*(sides+1),last=first+sides;
                normals[first]=normals[last]=(normals[first]+normals[last]).normalized;
            }
            mesh.normals=normals;EditorUtility.SetDirty(mesh);return mesh;
        }

        static Mesh Fin(string name,Vector2[] outline)
        {
            var v=new List<Vector3>();var uv=new List<Vector2>();var tr=new List<int>();
            Vector2 center=Vector2.zero;foreach(var p in outline)center+=p;center/=outline.Length;
            // Two curved faces and a beveled rim form a closed, genuinely 3D fin.
            int n=outline.Length;
            for(int side=0;side<2;side++)
            {
                float sign=side==0?-1:1;
                v.Add(new Vector3(sign*.038f,center.y,center.x));uv.Add(new Vector2(.5f,0));
                for(int i=0;i<n;i++)
                {
                    var p=outline[i];v.Add(new Vector3(sign*.010f,p.y,p.x));uv.Add(new Vector2(i/(float)n,1));
                }
                int offset=side*(n+1);
                for(int i=0;i<n;i++)
                {
                    int a=offset,b=offset+1+i,c=offset+1+(i+1)%n;
                    if(side==0) {tr.Add(a);tr.Add(b);tr.Add(c);} else {tr.Add(a);tr.Add(c);tr.Add(b);}
                }
            }
            for(int i=0;i<n;i++)Quad(tr,1+i,1+(i+1)%n,n+2+i,n+2+(i+1)%n);
            return SaveMesh(name,v,uv,tr);
        }

        static Mesh Tube(string name,List<Vector3> points,float radius)
        {
            var v=new List<Vector3>();var uv=new List<Vector2>();var tr=new List<int>();const int sides=10;
            for(int i=0;i<points.Count;i++)
            {
                Vector3 tangent=(points[Mathf.Min(i+1,points.Count-1)]-points[Mathf.Max(0,i-1)]).normalized;
                Vector3 right=Vector3.Cross(tangent,Mathf.Abs(tangent.z)<.9f?Vector3.forward:Vector3.up).normalized;
                Vector3 up=Vector3.Cross(tangent,right);
                for(int j=0;j<=sides;j++)
                {
                    float a=j/(float)sides*Mathf.PI*2;v.Add(points[i]+radius*(right*Mathf.Cos(a)+up*Mathf.Sin(a)));
                    uv.Add(new Vector2(i/(float)(points.Count-1),j/(float)sides));
                    if(i<points.Count-1&&j<sides)Quad(tr,i*(sides+1)+j,i*(sides+1)+j+1,(i+1)*(sides+1)+j,(i+1)*(sides+1)+j+1);
                }
            }
            return SaveMesh(name,v,uv,tr);
        }

        static void Quad(List<int> t,int a,int b,int c,int d) {t.Add(a);t.Add(b);t.Add(c);t.Add(c);t.Add(b);t.Add(d);}
        static Mesh SaveMesh(string name,List<Vector3> v,List<Vector2> uv,List<int> tr)
        {
            string path=Art+"/"+name+".asset";var mesh=AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if(mesh==null){mesh=new Mesh{name=name};AssetDatabase.CreateAsset(mesh,path);}else mesh.Clear();
            mesh.SetVertices(v);mesh.SetUVs(0,uv);mesh.SetTriangles(tr,0);mesh.RecalculateNormals();mesh.RecalculateTangents();mesh.RecalculateBounds();EditorUtility.SetDirty(mesh);return mesh;
        }
        static GameObject Part(Transform parent,string name,Mesh mesh,Material material)
        {
            var obj=new GameObject(name,typeof(MeshFilter),typeof(MeshRenderer));obj.transform.SetParent(parent,false);
            obj.GetComponent<MeshFilter>().sharedMesh=mesh;var renderer=obj.GetComponent<MeshRenderer>();
            renderer.sharedMaterial=material;renderer.shadowCastingMode=ShadowCastingMode.Off;return obj;
        }
        static void Sphere(Transform parent,string name,Vector3 position,Vector3 scale,Material material)
        {
            string path=Art+"/DetailSphere.asset";
            var mesh=AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if(mesh==null)
            {
                var primitive=GameObject.CreatePrimitive(PrimitiveType.Sphere);
                mesh=Object.Instantiate(primitive.GetComponent<MeshFilter>().sharedMesh);
                Object.DestroyImmediate(primitive);
                AssetDatabase.CreateAsset(mesh,path);
            }
            var obj=Part(parent,name,mesh,material);obj.transform.localPosition=position;obj.transform.localScale=scale;
        }

        public static void RenderViews()
        {
            var scene=EditorSceneManager.NewPreviewScene();var previous=RenderTexture.active;
            var target=new RenderTexture(1800,720,24);Texture2D image=null;
            try
            {
                var model=Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(PrefabPath));SceneManager.MoveGameObjectToScene(model,scene);
                model.GetComponent<GoldenReferenceFishMotion>().enabled=false;
                var cameraObject=new GameObject("Preview camera",typeof(Camera));SceneManager.MoveGameObjectToScene(cameraObject,scene);
                var camera=cameraObject.GetComponent<Camera>();camera.scene=scene;camera.targetTexture=target;
                camera.orthographic=true;camera.orthographicSize=1.95f;camera.backgroundColor=new Color(.065f,.13f,.18f);camera.clearFlags=CameraClearFlags.SolidColor;
                var key=new GameObject("Studio light",typeof(Light));SceneManager.MoveGameObjectToScene(key,scene);
                key.GetComponent<Light>().type=LightType.Directional;key.GetComponent<Light>().intensity=1.1f;
                var fill=new GameObject("Fill light",typeof(Light));SceneManager.MoveGameObjectToScene(fill,scene);
                fill.GetComponent<Light>().type=LightType.Directional;fill.GetComponent<Light>().intensity=.55f;
                Vector3[] positions={new Vector3(0,.05f,6),new Vector3(6,0,0),new Vector3(0,6,0)};
                string[] names={"FRONT","SIDE","TOP"};
                for(int i=0;i<3;i++)
                {
                    camera.rect=new Rect(i/3f,0,1/3f,1);Vector3 focus=new Vector3(0,0,-.35f);camera.transform.position=positions[i]+focus;
                    camera.transform.LookAt(focus,i==2?Vector3.left:Vector3.up);
                    key.transform.rotation=camera.transform.rotation*Quaternion.Euler(25,-30,0);
                    fill.transform.rotation=camera.transform.rotation*Quaternion.Euler(-20,130,0);
                    var label=new GameObject("View label",typeof(TextMesh));SceneManager.MoveGameObjectToScene(label,scene);
                    label.transform.position=camera.transform.up*-1.5f-camera.transform.forward*2;
                    label.transform.rotation=camera.transform.rotation;
                    var text=label.GetComponent<TextMesh>();text.text=names[i];text.anchor=TextAnchor.MiddleCenter;text.fontSize=48;text.characterSize=.055f;text.color=new Color(.85f,.91f,.95f);
                    camera.Render();Object.DestroyImmediate(label);
                }
                RenderTexture.active=target;image=new Texture2D(1800,720,TextureFormat.RGB24,false);image.ReadPixels(new Rect(0,0,1800,720),0,0);image.Apply();
                Directory.CreateDirectory("ArtPreviews");File.WriteAllBytes("ArtPreviews/golden-reference-three-views.png",image.EncodeToPNG());
                Debug.Log("[GoldenFish] Actual model preview saved to ArtPreviews/golden-reference-three-views.png. No player build.");
            }
            finally {RenderTexture.active=previous;if(image!=null)Object.DestroyImmediate(image);Object.DestroyImmediate(target);EditorSceneManager.ClosePreviewScene(scene);}
        }
    }
}
