using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace Chinsekid.FishGame.Editor
{
    public static partial class ReferenceFishCollectionSetup
    {
        // Original volumetric interpretation of the user's side/front/top references.
        static void BuildIridescentShark()
        {
            folder = Base + "/IridescentShark";
            Directory.CreateDirectory(folder);
            AssetDatabase.Refresh();
            meshId = 0;
            body = Mat("Iridescent blue skin", Color.white, .46f);
            body.mainTexture = SharkPaint(false);
            body.SetFloat("_Metallic", .24f);
            fin = Mat("Blue edged fins", Color.white, .36f);
            fin.mainTexture = SharkPaint(true);
            fin.SetFloat("_Metallic", .18f);
            belly = Mat("Pearl white belly", new Color(.80f, .84f, .86f), .42f);
            dark = Mat("Mouth and gill cavities", new Color(.025f, .035f, .055f), .25f);
            ivory = Mat("Small ivory teeth", new Color(.93f, .94f, .89f), .48f);
            iris = Mat("Copper amber eyes", new Color(.73f, .31f, .12f), .68f);
            lip = Mat("Subtle mouth rim", new Color(.29f, .23f, .28f), .34f);
            var snout = Mat("Blue grey snout", new Color(.26f, .36f, .49f), .36f);
            var root = new GameObject("IridescentShark");
            var sculpt = Joint(root.transform, "Normalized sculpture", Vector3.zero);
            var motion = root.AddComponent<GoldenReferenceFishMotion>();
            try
            {
                Part(sculpt, "Streamlined shark hull", SharkHull(), body);
                motion.tail = Joint(sculpt, "Crescent tail joint", new Vector3(0, .015f, -1.28f));
                Part(motion.tail, "Lunate tail", SharkFin(new[] {
                    new Vector2(.11f, .07f), new Vector2(-.49f, .89f),
                    new Vector2(-.74f, 1.01f), new Vector2(-.65f, .72f),
                    new Vector2(-.34f, .08f), new Vector2(-.35f, -.09f),
                    new Vector2(-.67f, -.78f), new Vector2(-.75f, -.94f),
                    new Vector2(-.47f, -.72f), new Vector2(.11f, -.06f)
                }), fin);
                Part(sculpt, "Swept tall dorsal", SharkFin(new[] {
                    new Vector2(-.65f,.30f),new Vector2(-.41f,.51f),
                    new Vector2(-.12f,1.02f),new Vector2(.02f,1.12f),
                    new Vector2(.06f,.98f),new Vector2(.03f,.65f),new Vector2(.36f,.41f)
                }), fin);
                Part(sculpt, "Second dorsal", SharkFin(new[] {
                    new Vector2(-1.03f,.13f),new Vector2(-.85f,.35f),new Vector2(-.68f,.24f)
                }), fin);
                Part(sculpt, "Anal fin", SharkFin(new[] {
                    new Vector2(-1.04f,-.13f),new Vector2(-.88f,-.37f),new Vector2(-.66f,-.25f)
                }), fin);
                for (int side = -1; side <= 1; side += 2)
                {
                    var pivot = Joint(sculpt, side < 0 ? "Left pectoral joint" : "Right pectoral joint",
                        new Vector3(side * .38f, -.17f, .24f));
                    Part(pivot, "Long swept pectoral", SharkWing(side), fin);
                    pivot.localRotation = Quaternion.Euler(0, side * 25, side * 16);
                    if (side < 0) motion.leftFin = pivot; else motion.rightFin = pivot;
                    var pelvic = Part(sculpt, "Paired pelvic fin", SharkFin(new[] {
                        new Vector2(-.55f,-.19f),new Vector2(-.94f,-.48f),new Vector2(-.55f,-.40f),new Vector2(-.36f,-.23f)
                    }), fin);
                    pelvic.transform.localRotation = Quaternion.Euler(0, side * 40, 0);
                    pelvic.transform.localPosition = new Vector3(side * .17f, 0, 0);
                    var eyeAt = new Vector3(side * .40f, .16f, .77f);
                    Eye(sculpt, side, eyeAt, .135f);
                    Curve(sculpt, "Angled blue brow", eyeAt + new Vector3(-side*.085f,.075f,.075f),
                        eyeAt + new Vector3(0,.055f,.09f), eyeAt + new Vector3(side*.09f,.115f,-.02f), .018f, snout);
                    Ball(sculpt, "Nostril", new Vector3(side*.21f,.027f,1.155f), new Vector3(.045f,.025f,.014f), dark);
                    for (int slit = 0; slit < 3; slit++)
                    {
                        float z = .43f - slit * .105f;
                        Curve(sculpt, "Three recessed gill slits", new Vector3(side*.414f,.25f,z),
                            new Vector3(side*.493f,.02f,z-.02f), new Vector3(side*.432f,-.22f,z-.055f), .012f, dark);
                    }
                }
                SharkMouth(sculpt);
                Ball(sculpt, "Broad rounded upper snout", new Vector3(0,.045f,.86f), new Vector3(.90f,.46f,.68f), snout);
                Bake(sculpt); Bake(motion.tail); Bake(motion.leftFin); Bake(motion.rightFin);
                Bounds bounds = new Bounds(); bool has = false;
                foreach (var mf in root.GetComponentsInChildren<MeshFilter>())
                foreach (var v in mf.sharedMesh.vertices)
                {
                    var at = root.transform.InverseTransformPoint(mf.transform.TransformPoint(v));
                    if (!has) { bounds = new Bounds(at, Vector3.zero); has = true; } else bounds.Encapsulate(at);
                }
                float scale = Mathf.Min(2.65f / bounds.size.z, 1.65f / bounds.size.x, 1.65f / bounds.size.y);
                sculpt.localScale = Vector3.one * scale;
                sculpt.localPosition = -bounds.center * scale;
                PrefabUtility.SaveAsPrefabAsset(root, "Assets/Resources/OpenSea/Fish/IridescentShark.prefab");
                Debug.Log("[IridescentShark] Generated normalized mesh with animated tail/fins and 3D mouth/teeth.");
            }
            finally { Object.DestroyImmediate(root); }
        }

        static Mesh SharkFin(Vector2[] outline)
        {
            var smooth=new List<Vector2>();
            for(int i=0;i<outline.Length;i++)
            {
                Vector2 a=outline[i],b=outline[(i+1)%outline.Length];
                smooth.Add(Vector2.Lerp(a,b,.10f));
                smooth.Add(Vector2.Lerp(a,b,.90f));
            }
            return Fin(smooth.ToArray());
        }

        static Mesh SharkWing(int side)
        {
            Vector2[] outline = {
                new Vector2(0,.16f),new Vector2(.35f,-.05f),new Vector2(.94f,-.67f),
                new Vector2(1.01f,-.82f),new Vector2(.67f,-.73f),new Vector2(.07f,-.22f)
            };
            var v=new List<Vector3>();var uv=new List<Vector2>();var tr=new List<int>();
            // A lens-shaped solid wing: top/bottom ridges taper to a thin perimeter.
            v.Add(new Vector3(side*.35f,.014f,-.28f));uv.Add(new Vector2(.5f,.5f));
            v.Add(new Vector3(side*.35f,-.014f,-.28f));uv.Add(new Vector2(.5f,.5f));
            foreach(var p in outline){v.Add(new Vector3(side*p.x,0,p.y));uv.Add(new Vector2(p.x,1+p.y));}
            for(int i=0;i<outline.Length;i++)
            {
                int a=2+i,b=2+(i+1)%outline.Length;
                if(side>0){Tri(tr,0,a,b);Tri(tr,1,b,a);}
                else{Tri(tr,0,b,a);Tri(tr,1,a,b);}
            }
            return Mesh(v,uv,tr);
        }

        static Mesh SharkHull()
        {
            var vertices = new List<Vector3>(); var uv = new List<Vector2>(); var triangles = new List<int>();
            const int rings = 64, sides = 48;
            var width = new AnimationCurve(new Keyframe(0,.035f), new Keyframe(.20f,.16f),
                new Keyframe(.46f,.40f),new Keyframe(.67f,.51f),new Keyframe(.83f,.44f),new Keyframe(1,.34f));
            var height = new AnimationCurve(new Keyframe(0,.045f),new Keyframe(.25f,.21f),
                new Keyframe(.53f,.43f),new Keyframe(.72f,.44f),new Keyframe(.87f,.31f),new Keyframe(1,.105f));
            for (int i = 0; i <= rings; i++)
            for (int j = 0; j <= sides; j++)
            {
                float t = i / (float)rings, v = j / (float)sides, angle = v * Mathf.PI * 2;
                float mouth = Smooth(.83f, 1, t);
                vertices.Add(new Vector3(Mathf.Cos(angle)*width.Evaluate(t),
                    Mathf.Sin(angle)*height.Evaluate(t) - mouth*.13f, Mathf.Lerp(-1.36f,1.12f,t)));
                uv.Add(new Vector2(t,v));
                if (i < rings && j < sides) { int k = i*(sides+1)+j; Quad(triangles,k,k+1,k+sides+1,k+sides+2); }
            }
            var mesh = Mesh(vertices, uv, triangles);
            var normals = mesh.normals;
            for (int i=0;i<=rings;i++) { int a=i*(sides+1),b=a+sides; normals[a]=normals[b]=(normals[a]+normals[b]).normalized; }
            mesh.normals=normals;
            return mesh;
        }

        static void SharkMouth(Transform parent)
        {
            const float w=.34f,h=.105f,cy=-.13f,z=1.125f;
            var vertices=new List<Vector3>();var uv=new List<Vector2>();var triangles=new List<int>();
            const int rings=8,sides=48;
            for(int i=0;i<=rings;i++)for(int j=0;j<=sides;j++)
            {
                float r=i/(float)rings,a=j/(float)sides*Mathf.PI*2;
                vertices.Add(new Vector3(Mathf.Cos(a)*w*r,cy+Mathf.Sin(a)*h*r,z-.22f*(1-r*r)));
                uv.Add(new Vector2(r,j/(float)sides));
                if(i<rings&&j<sides){int k=i*(sides+1)+j;Tri(triangles,k,k+sides+1,k+1);Tri(triangles,k+1,k+sides+1,k+sides+2);}
            }
            Part(parent,"Recessed narrow smile",Mesh(vertices,uv,triangles),dark);
            var rim=new List<Vector3>();
            for(int i=0;i<=64;i++){float a=i/64f*Mathf.PI*2;rim.Add(new Vector3(Mathf.Cos(a)*w,cy+Mathf.Sin(a)*h,z));}
            Part(parent,"Fine lip edge",Tube(rim,.013f),lip);
            Ball(parent,"Pale lower jaw",new Vector3(0,-.255f,.94f),new Vector3(.76f,.17f,.49f),belly);
            for(int row=0;row<2;row++)for(int i=0;i<15;i++)
            {
                float x=Mathf.Lerp(-.31f,.31f,(i+.5f)/15);
                float edge=Mathf.Sqrt(Mathf.Max(0,1-x*x/(w*w)));
                float y=cy+(row==0?1:-1)*h*edge;
                var at=new Vector3(x,y,z+.003f);
                Part(parent,"Small triangular shark tooth",Cone(at,at+new Vector3(0,row==0?-.054f:.041f,-.018f),.021f),ivory);
            }
        }

        static Texture2D SharkPaint(bool fins)
        {
            const int width=1024,height=512;
            var texture=new Texture2D(width,height,TextureFormat.RGB24,false);
            var pixels=new Color[width*height];
            for(int y=0;y<height;y++)for(int x=0;x<width;x++)
            {
                float u=x/(float)(width-1),v=y/(float)(height-1),top=Mathf.Sin(v*Mathf.PI*2);
                float grain=Mathf.PerlinNoise(u*185,v*140);
                var blue=Color.Lerp(new Color(.19f,.27f,.39f),new Color(.35f,.46f,.59f),grain);
                float ripple=(Mathf.PerlinNoise(u*37+3,v*29)-.5f)*.13f;
                float white=1-Smooth(-.23f+ripple,-.08f+ripple,top);
                Color color=Color.Lerp(blue,new Color(.81f,.85f,.87f),white);
                if(!fins)
                {
                    float patch=Mathf.PerlinNoise(u*39+Mathf.Sin(v*24)*.7f,v*21);
                    float mask=Smooth(.54f,.68f,patch)*Smooth(-.04f,.40f,top)*(1-Smooth(.79f,.94f,u));
                    var sheen=Color.HSVToRGB(Mathf.Repeat(u*1.5f+v*2.8f+patch*.8f,.75f)+.12f,.48f,.76f);
                    color=Color.Lerp(color,sheen,mask*.76f);
                }
                else
                {
                    float edge=Smooth(.83f,.99f,v);
                    color=Color.Lerp(blue,new Color(.17f,.61f,.67f),edge*.67f);
                }
                pixels[y*width+x]=color*(.96f+grain*.08f);
            }
            texture.SetPixels(pixels);texture.Apply();
            string path=folder+(fins?"/SharkFins.png":"/SharkSkin.png");
            File.WriteAllBytes(path,texture.EncodeToPNG());Object.DestroyImmediate(texture);
            AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
            return AssetDatabase.LoadAssetAtPath<Texture2D>(path);
        }
    }
}
