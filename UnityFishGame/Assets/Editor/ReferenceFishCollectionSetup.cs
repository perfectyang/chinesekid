using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace Chinsekid.FishGame.Editor
{
    // Real volumetric meshes, forward +Z. Hidden surfaces are modeled interpretations.
    public static partial class ReferenceFishCollectionSetup
    {
        static readonly string[] Names = { "PatternedReef", "RubyLionfish", "SpottedPuffer", "AzureAngelfish", "FangHunter", "GrinningShark", "IridescentShark" };
        const string Base = "Assets/Art/ReferenceFishCollection";
        static string folder;
        static int meshId;
        static Mesh sphere;
        static Material body, fin, belly, dark, ivory, iris, lip;

        [MenuItem("Chinsekid/Fish Game/Create Reference Fish Collection")]
        public static void PrepareAndRender()
        {
            Directory.CreateDirectory(Base);
            Directory.CreateDirectory("Assets/Resources/OpenSea/Fish");
            AssetDatabase.Refresh();
            var primitive = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            sphere = Object.Instantiate(primitive.GetComponent<MeshFilter>().sharedMesh);
            Object.DestroyImmediate(primitive);
            SaveMeshAsset(sphere, Base + "/SharedDetailSphere.asset");
            sphere = AssetDatabase.LoadAssetAtPath<Mesh>(Base + "/SharedDetailSphere.asset");
            for (int species = 0; species < Names.Length; species++) Build(species);
            AssetDatabase.SaveAssets();
            RenderGallery();
            Debug.Log("[ReferenceFish] Created all seven normalized animated 3D prefabs and actual model previews.");
        }

        static void Build(int species)
        {
            if (species == 6) { BuildIridescentShark(); return; }
            folder = Base + "/" + Names[species]; Directory.CreateDirectory(folder); AssetDatabase.Refresh(); meshId = 0;
            Color[] colors = { new Color(.84f,.58f,.20f), new Color(.76f,.13f,.12f), new Color(.59f,.69f,.31f), new Color(.24f,.67f,.82f), new Color(.26f,.47f,.49f), new Color(.20f,.48f,.64f) };
            Color[] finColors = { new Color(.12f,.46f,.49f), new Color(.93f,.29f,.23f), new Color(.62f,.65f,.23f), new Color(.30f,.70f,.86f), new Color(.27f,.35f,.32f), new Color(.14f,.36f,.49f) };
            body = Mat("Painted body", Color.white, .28f); body.mainTexture = Paint(species, false, colors[species]);
            fin = Mat("Ribbed fins", Color.white, .32f); fin.mainTexture = Paint(species, true, finColors[species]);
            belly = Mat("Warm belly", species == 5 ? new Color(.76f,.83f,.81f) : new Color(.94f,.70f,.35f), .22f);
            dark = Mat("Mouth and pupil", new Color(.025f,.035f,.042f), .3f);
            ivory = Mat("Ivory", new Color(.96f,.94f,.79f), .45f);
            iris = Mat("Iris", species == 4 ? new Color(.89f,.24f,.065f) : new Color(.30f,.60f,.63f), .7f);
            lip = Mat("Lip and gill", species == 5 ? new Color(.45f,.22f,.24f) : new Color(.75f,.39f,.16f), .3f);
            var root = new GameObject(Names[species]); var sculpt = new GameObject("Normalized sculpture").transform; sculpt.SetParent(root.transform,false);
            var motion = root.AddComponent<GoldenReferenceFishMotion>();
            try
            {
                float width = species == 2 ? .70f : species == 3 ? .20f : species == 5 ? .66f : species == 4 ? .33f : .43f;
                float height = species == 2 ? .66f : species == 3 ? .77f : species == 5 ? .65f : species == 4 ? .44f : .56f;
                float length = species == 4 ? 2.12f : species == 5 ? 2.18f : species == 2 ? 1.80f : 1.94f;
                Part(sculpt, "Sculpted body", Hull(width,height,length,species), body);
                motion.tail = Joint(sculpt,"Tail joint",new Vector3(0,0,-length*.46f));
                float tailHeight = species == 5 ? .89f : species == 3 ? .63f : species == 2 ? .32f : .62f;
                Part(motion.tail, "Fan tail", Fin(new[] { new Vector2(.12f,0),new Vector2(-.68f,tailHeight),new Vector2(-.80f,tailHeight*.92f),new Vector2(-.58f,0),new Vector2(-.80f,-tailHeight*.92f),new Vector2(-.68f,-tailHeight),new Vector2(.12f,0) }),fin);
                if (species == 0) ReefDorsal(sculpt);
                else if (species == 1) LionFins(sculpt);
                else if (species == 2) PufferSpikes(sculpt);
                else if (species == 3) AngelFins(sculpt);
                else Part(sculpt,"Swept dorsal",Fin(new[] {new Vector2(-.7f,.22f),new Vector2(-.36f,1.10f),new Vector2(.25f,.48f),new Vector2(.52f,.30f)}),fin);
                if (species != 3 && species != 1)
                    Part(sculpt,"Lower rear fin",Fin(new[] {new Vector2(-.75f,-.21f),new Vector2(-.48f,-.73f),new Vector2(-.16f,-.42f),new Vector2(.18f,-.29f)}),fin);
                for (int side=-1;side<=1;side+=2)
                {
                    var pivot=Joint(sculpt,side<0?"Left fin joint":"Right fin joint",new Vector3(side*width*.79f,-.07f,.14f));
                    var wing=Part(pivot,"Pectoral fin",Fin(new[] {new Vector2(.18f,.12f),new Vector2(-.20f,.20f),new Vector2(-.65f,-.13f),new Vector2(-.72f,-.35f),new Vector2(-.21f,-.27f),new Vector2(.15f,-.08f)}),fin);
                    wing.transform.localRotation=Quaternion.Euler(0,side*(species==5?67:48),species==5?side*-17:0);
                    if(species==5)wing.transform.localScale=new Vector3(1,1.7f,1.6f);
                    if(species==1)wing.transform.localScale=new Vector3(1,1.7f,1.35f);
                    pivot.localRotation=Quaternion.Euler(0,side*25,side*16);
                    if(side<0)motion.leftFin=pivot;else motion.rightFin=pivot;
                    float eyeZ=species==5?.70f:species==4?.72f:.64f;
                    float eyeY=species==5?.36f:species==4?.39f:.23f;
                    Eye(sculpt,side,new Vector3(side*width*.73f,eyeY,eyeZ),species==5?.24f:species==2?.24f:.20f);
                    var points=new List<Vector3>();
                    for(int j=0;j<=16;j++){float t=j/16f;points.Add(new Vector3(side*width*.96f,Mathf.Lerp(-height*.58f,height*.57f,t),.28f-.13f*Mathf.Sin(t*Mathf.PI)));}
                    Part(sculpt,"Curved gill",Tube(points,.013f),species==0?fin:lip);
                }
                if(species==4 || species==5) OpenMouth(sculpt,species==5);
                else
                {
                    Ball(sculpt,"Rounded muzzle",new Vector3(0,-.06f,.87f),new Vector3(width*1.15f,.30f,.37f),species==0?belly:body);
                    Ball(sculpt,"Mouth slit",new Vector3(0,-.10f,1.04f),new Vector3(.24f,.065f,.04f),dark);
                    Curve(sculpt,"Lower lip",new Vector3(-.13f,-.12f,1.05f),new Vector3(0,-.15f,1.08f),new Vector3(.13f,-.12f,1.05f),.025f,lip);
                }
                // Merge static details by material, keeping the three animated joints independent.
                Bake(sculpt); Bake(motion.tail); Bake(motion.leftFin); Bake(motion.rightFin);
                Bounds bounds=new Bounds();bool has=false;
                foreach(var mf in root.GetComponentsInChildren<MeshFilter>())
                foreach(var v in mf.sharedMesh.vertices){var p=root.transform.InverseTransformPoint(mf.transform.TransformPoint(v));if(!has){bounds=new Bounds(p,Vector3.zero);has=true;}else bounds.Encapsulate(p);}
                float scale=Mathf.Min(2.65f/bounds.size.z,1.65f/bounds.size.x,1.65f/bounds.size.y);
                sculpt.localScale=Vector3.one*scale;sculpt.localPosition=-bounds.center*scale;
                PrefabUtility.SaveAsPrefabAsset(root,"Assets/Resources/OpenSea/Fish/"+Names[species]+".prefab");
            }
            finally{Object.DestroyImmediate(root);}
        }

        static void ReefDorsal(Transform p)
        {
            var shape=new List<Vector2>{new Vector2(-.86f,.20f)};
            for(int i=0;i<=16;i++){float t=i/16f;shape.Add(new Vector2(Mathf.Lerp(-.78f,.65f,t),.48f+.36f*Mathf.Sin(t*Mathf.PI)+.035f*(i%2)));}
            shape.Add(new Vector2(.72f,.24f));Part(p,"Scalloped teal crest",Fin(shape.ToArray()),fin);
        }
        static void LionFins(Transform p)
        {
            var shape=new List<Vector2>{new Vector2(-.89f,.20f)};
            for(int i=0;i<10;i++)
            {
                float z=-.8f+i*.15f, h=.85f+.43f*Mathf.Sin((i+.5f)/10*Mathf.PI);
                shape.Add(new Vector2(z-.13f,h));shape.Add(new Vector2(z+.055f,.49f));
            }
            shape.Add(new Vector2(.75f,.20f));Part(p,"Long striped dorsal spines",Fin(shape.ToArray()),fin);
            Part(p,"Flowing striped lower fan",Fin(new[] {new Vector2(-.85f,-.19f),new Vector2(-.70f,-.81f),new Vector2(-.45f,-.91f),new Vector2(-.12f,-.83f),new Vector2(.28f,-.53f),new Vector2(.52f,-.21f)}),fin);
        }
        static void AngelFins(Transform p)
        {
            Part(p,"Tall swept dorsal",Fin(new[] {new Vector2(-.78f,.13f),new Vector2(-.90f,1.40f),new Vector2(-.39f,1.13f),new Vector2(.25f,.65f),new Vector2(.57f,.21f)}),fin);
            Part(p,"Tall swept ventral",Fin(new[] {new Vector2(-.78f,-.13f),new Vector2(-.88f,-1.25f),new Vector2(-.35f,-.92f),new Vector2(.29f,-.52f),new Vector2(.57f,-.21f)}),fin);
            for(int s=-1;s<=1;s+=2)Curve(p,"Long pelvic feeler",new Vector3(s*.11f,-.31f,.36f),new Vector3(s*.15f,-.77f,.05f),new Vector3(s*.19f,-1.20f,-.36f),.012f,ivory);
        }
        static void PufferSpikes(Transform p)
        {
            const int count=52;float golden=Mathf.PI*(3-Mathf.Sqrt(5));
            for(int i=0;i<count;i++)
            {
                float y=1-2*(i+.5f)/count;float r=Mathf.Sqrt(1-y*y),a=i*golden;
                var n=new Vector3(Mathf.Cos(a)*r,y,Mathf.Sin(a)*r);
                if(n.z>.68f)continue;
                var point=new Vector3(n.x*.65f,n.y*.63f,n.z*.83f);
                Part(p,"Small ivory spine",Cone(point,point+n*.10f,.028f),ivory);
            }
            Part(p,"Little dorsal",Fin(new[] {new Vector2(-.67f,.25f),new Vector2(-.60f,.83f),new Vector2(-.20f,.75f),new Vector2(.05f,.45f)}),fin);
        }
        static void OpenMouth(Transform p,bool shark)
        {
            float w=shark?.51f:.29f,h=shark?.28f:.45f,z=shark?.95f:1.04f,cy=shark?-.16f:.06f;
            // A deep concave bowl provides a real cavity rather than a flat painted mouth.
            var vertices=new List<Vector3>();var uv=new List<Vector2>();var triangles=new List<int>();const int rings=8,sides=48;
            for(int i=0;i<=rings;i++)for(int j=0;j<=sides;j++)
            {
                float r=i/(float)rings,a=j/(float)sides*Mathf.PI*2;
                vertices.Add(new Vector3(Mathf.Cos(a)*w*r,cy+Mathf.Sin(a)*h*r,z-.35f*(1-r*r)));
                uv.Add(new Vector2(r,j/(float)sides));
                if(i<rings&&j<sides){int k=i*(sides+1)+j;Tri(triangles,k,k+sides+1,k+1);Tri(triangles,k+1,k+sides+1,k+sides+2);}
            }
            Part(p,"Deep open mouth cavity",Mesh(vertices,uv,triangles),dark);
            var rim=new List<Vector3>();for(int i=0;i<=64;i++){float a=i/64f*Mathf.PI*2;rim.Add(new Vector3(Mathf.Cos(a)*w,cy+Mathf.Sin(a)*h,z));}
            Part(p,"Sculpted mouth rim",Tube(rim,shark?.036f:.048f),lip);
            Ball(p,"Rounded lower jaw",new Vector3(0,cy-h-.075f,z-.15f),new Vector3(w*1.9f,.25f,.52f),shark?belly:body);
            // Teeth line the opening and point inward; fangs are deliberately larger at the corners.
            for(int i=0;i<(shark?22:12);i++)
            {
                int count=shark?22:12;float a=(i+.5f)/count*Mathf.PI*2;
                var at=new Vector3(Mathf.Cos(a)*w*.92f,cy+Mathf.Sin(a)*h*.92f,z+.005f);
                float fang=shark?.105f:(i%3==0?.22f:.12f);
                var inward=new Vector3(-Mathf.Cos(a)*.32f,-Mathf.Sin(a),-.20f).normalized;
                Part(p,"Individual pointed tooth",Cone(at,at+inward*fang,shark?.039f:.044f),ivory);
            }
            if(shark)
            {
                Ball(p,"Broad blue snout",new Vector3(0,.24f,.73f),new Vector3(1.10f,.42f,.83f),body);
                for(int s=-1;s<=1;s+=2)
                    Ball(p,"Nostril",new Vector3(s*.21f,.17f,1.10f),new Vector3(.085f,.035f,.025f),dark);
            }
        }
        static void Eye(Transform p,int side,Vector3 at,float size)
        {
            var q=Quaternion.LookRotation(new Vector3(side*.82f,.10f,.57f));
            Ball(p,"Eye white",at,new Vector3(size,size*1.07f,size*.45f),ivory,q);
            Ball(p,"Colored iris",at+q*Vector3.forward*size*.20f,new Vector3(size*.70f,size*.76f,size*.28f),iris,q);
            Ball(p,"Dark pupil",at+q*Vector3.forward*size*.34f,new Vector3(size*.42f,size*.51f,size*.15f),dark,q);
            Ball(p,"Eye glint",at+q*new Vector3(-size*.13f,size*.20f,size*.42f),Vector3.one*size*.15f,ivory,q);
        }
        static float Smooth(float a,float b,float value)=>Mathf.SmoothStep(0,1,Mathf.InverseLerp(a,b,value));
        static Texture2D Paint(int species,bool fins,Color baseColor)
        {
            const int w=512,h=256;var tex=new Texture2D(w,h,TextureFormat.RGB24,false);
            for(int y=0;y<h;y++)for(int x=0;x<w;x++)
            {
                float u=x/(float)(w-1),v=y/(float)(h-1),top=Mathf.Sin(v*Mathf.PI*2);
                Color c=Color.Lerp(baseColor,new Color(.97f,.88f,.61f),Mathf.Max(0,-top)*.58f);
                c=Color.Lerp(c,baseColor*.60f,Mathf.Max(0,top)*.30f);
                float noise=(Mathf.PerlinNoise(u*150+species*23,v*90)-.5f)*.12f;c*=1+noise;
                if(species==0)
                {
                    float row=Mathf.Floor(v*9),xx=Mathf.Repeat(u*11+row*.43f,1)-.5f,yy=Mathf.Repeat(v*9,1)-.5f;
                    float ring=Mathf.Abs(Mathf.Sqrt(xx*xx*1.4f+yy*yy)-.32f);
                    c=Color.Lerp(c,new Color(1,.86f,.39f),(1-Smooth(.025f,.07f,ring))*.8f);
                }
                else if(species==1)
                {
                    float stripe=Mathf.Abs(Mathf.Sin((u*12+Mathf.Sin(v*18)*.16f)*Mathf.PI));
                    c=Color.Lerp(c,new Color(1,.88f,.68f),1-Smooth(.12f,.29f,stripe));
                }
                else if(species==2)
                {
                    float row=Mathf.Floor(v*8),xx=Mathf.Repeat(u*9+row*.47f,1)-.5f,yy=Mathf.Repeat(v*8,1)-.5f;
                    float spot=Mathf.Sqrt(xx*xx+yy*yy);
                    c=Color.Lerp(c,new Color(.39f,.23f,.12f),1-Smooth(.15f,.22f,spot));
                    c=Color.Lerp(c,new Color(.86f,.88f,.51f),(1-Smooth(.025f,.06f,Mathf.Abs(spot-.27f)))*.7f);
                }
                else if(species==3)
                {
                    float stripe=Mathf.Abs(Mathf.Sin((u*4.8f+v*.13f)*Mathf.PI));
                    c=Color.Lerp(c,new Color(.035f,.11f,.15f),1-Smooth(.15f,.37f,stripe));
                }
                else if(species==4)
                {
                    c=Color.Lerp(new Color(.87f,.51f,.18f),baseColor,Smooth(-.15f,.35f,top));
                    float row=Mathf.Floor(v*16),xx=Mathf.Repeat(u*22+row*.5f,1)-.5f,yy=Mathf.Repeat(v*16,1)-.5f;
                    float edge=Mathf.Abs(new Vector2(xx,yy).magnitude-.43f);
                    c=Color.Lerp(c,new Color(.12f,.24f,.25f),(1-Smooth(.015f,.05f,edge))*.30f);
                }
                if(fins)
                {
                    float ray=Mathf.Pow(.5f+.5f*Mathf.Cos(u*90),10)*.36f;
                    c=Color.Lerp(c,baseColor*.36f,ray);
                    c=Color.Lerp(c,new Color(.90f,.75f,.36f),Smooth(.83f,1,v)*.5f);
                }
                tex.SetPixel(x,y,c);
            }
            tex.Apply();string path=folder+(fins?"/FinRays.png":"/BodyPattern.png");File.WriteAllBytes(path,tex.EncodeToPNG());Object.DestroyImmediate(tex);
            AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);return AssetDatabase.LoadAssetAtPath<Texture2D>(path);
        }
        static Mesh Hull(float width,float height,float length,int species)
        {
            var v=new List<Vector3>();var uv=new List<Vector2>();var tr=new List<int>();const int rings=40,sides=32;
            for(int i=0;i<=rings;i++)
            {
                float t=i/(float)rings,envelope=Mathf.Pow(Mathf.Max(0,Mathf.Sin(t*Mathf.PI)),species==2?.52f:.68f);
                float fullness=Mathf.Lerp(.28f,1,Mathf.SmoothStep(0,1,t/.56f));
                // Large-mouthed species end behind the lip so the bowl stays hollow.
                float front=species==5?.95f:species==4?1.04f:length*.53f;
                float mouthBlend=species>=4?Smooth(.62f,1,t):0;
                float ringW=Mathf.Lerp(width*envelope*fullness,species==5?.51f:.29f,mouthBlend);
                float ringH=Mathf.Lerp(height*envelope,species==5?.28f:.45f,mouthBlend);
                float centerY=mouthBlend*(species==5?-.16f:.06f);
                for(int j=0;j<=sides;j++)
                {
                    float a=j/(float)sides*Mathf.PI*2;
                    v.Add(new Vector3(Mathf.Cos(a)*ringW,centerY+Mathf.Sin(a)*ringH,Mathf.Lerp(-length*.5f,front,t)));
                    uv.Add(new Vector2(t,j/(float)sides));if(i<rings&&j<sides){int k=i*(sides+1)+j;Quad(tr,k,k+1,k+sides+1,k+sides+2);}
                }
            }
            var mesh=Mesh(v,uv,tr);var normals=mesh.normals;
            for(int i=0;i<=rings;i++){int first=i*(sides+1),last=first+sides;normals[first]=normals[last]=(normals[first]+normals[last]).normalized;}
            mesh.normals=normals;return mesh;
        }
        static Mesh Fin(Vector2[] outline)
        {
            var points=new List<Vector2>(outline);
            if(points.Count>2 && (points[0]-points[points.Count-1]).sqrMagnitude<.000001f)points.RemoveAt(points.Count-1);
            int n=points.Count;var polygon=new List<int>();float area=0;
            for(int i=0;i<n;i++)area+=Cross(points[i],points[(i+1)%n]);
            for(int i=0;i<n;i++)polygon.Add(area>0?i:n-1-i);
            var faces=new List<int>();int guard=n*n;
            while(polygon.Count>3 && guard-->0)
            {
                bool clipped=false;
                for(int i=0;i<polygon.Count;i++)
                {
                    int a=polygon[(i+polygon.Count-1)%polygon.Count],b=polygon[i],c=polygon[(i+1)%polygon.Count];
                    if(Cross(points[b]-points[a],points[c]-points[b])<=.000001f)continue;
                    bool inside=false;
                    foreach(int k in polygon)
                    {
                        if(k==a||k==b||k==c)continue;
                        if(Cross(points[b]-points[a],points[k]-points[a])>=-.000001f && Cross(points[c]-points[b],points[k]-points[b])>=-.000001f && Cross(points[a]-points[c],points[k]-points[c])>=-.000001f){inside=true;break;}
                    }
                    if(inside)continue;Tri(faces,a,b,c);polygon.RemoveAt(i);clipped=true;break;
                }
                if(!clipped)break;
            }
            if(polygon.Count==3)Tri(faces,polygon[0],polygon[1],polygon[2]);
            var v=new List<Vector3>();var uv=new List<Vector2>();var tr=new List<int>();
            float minY=float.MaxValue,maxY=float.MinValue;foreach(var point in points){minY=Mathf.Min(minY,point.y);maxY=Mathf.Max(maxY,point.y);}
            for(int side=0;side<2;side++)
            {
                foreach(var point in points){v.Add(new Vector3(side==0?-.014f:.014f,point.y,point.x));uv.Add(new Vector2((point.x+1)/2,Mathf.InverseLerp(minY,maxY,point.y)));}
                for(int i=0;i<faces.Count;i+=3){int a=faces[i]+side*n,b=faces[i+1]+side*n,c=faces[i+2]+side*n;Tri(tr,a,side==0?b:c,side==0?c:b);}
            }
            for(int i=0;i<n;i++)Quad(tr,i,(i+1)%n,n+i,n+(i+1)%n);
            return Mesh(v,uv,tr);
        }
        static float Cross(Vector2 a,Vector2 b)=>a.x*b.y-a.y*b.x;
        static Mesh Cone(Vector3 start,Vector3 end,float radius)
        {
            var v=new List<Vector3>();var uv=new List<Vector2>();var tr=new List<int>();var q=Quaternion.FromToRotation(Vector3.up,(end-start).normalized);const int sides=8;
            v.Add(end);uv.Add(new Vector2(.5f,1));v.Add(start);uv.Add(Vector2.zero);
            for(int i=0;i<sides;i++){float a=i/(float)sides*Mathf.PI*2;v.Add(start+q*new Vector3(Mathf.Cos(a)*radius,0,Mathf.Sin(a)*radius));uv.Add(new Vector2(i/(float)sides,0));}
            for(int i=0;i<sides;i++){int a=2+i,b=2+(i+1)%sides;Tri(tr,0,b,a);Tri(tr,1,a,b);}return Mesh(v,uv,tr);
        }
        static Mesh Tube(List<Vector3> points,float radius)
        {
            var v=new List<Vector3>();var uv=new List<Vector2>();var tr=new List<int>();const int sides=8;
            for(int i=0;i<points.Count;i++)
            {
                Vector3 tangent=(points[Mathf.Min(i+1,points.Count-1)]-points[Mathf.Max(0,i-1)]).normalized;
                Vector3 right=Vector3.Cross(tangent,Mathf.Abs(tangent.z)<.9f?Vector3.forward:Vector3.up).normalized,up=Vector3.Cross(tangent,right);
                for(int j=0;j<=sides;j++){float a=j/(float)sides*Mathf.PI*2;v.Add(points[i]+radius*(right*Mathf.Cos(a)+up*Mathf.Sin(a)));uv.Add(new Vector2(i/(float)(points.Count-1),j/(float)sides));if(i<points.Count-1&&j<sides){int k=i*(sides+1)+j;Quad(tr,k,k+1,k+sides+1,k+sides+2);}}
            }
            return Mesh(v,uv,tr);
        }
        static void Curve(Transform p,string name,Vector3 a,Vector3 b,Vector3 c,float radius,Material material)
        {var points=new List<Vector3>();for(int i=0;i<=20;i++){float t=i/20f;points.Add((1-t)*(1-t)*a+2*(1-t)*t*b+t*t*c);}Part(p,name,Tube(points,radius),material);}
        static Material Mat(string name,Color color,float gloss)
        {
            string path=folder+"/"+name+".mat";var m=AssetDatabase.LoadAssetAtPath<Material>(path);if(m==null){m=new Material(Shader.Find("Standard"));AssetDatabase.CreateAsset(m,path);}
            m.color=color;m.SetFloat("_Glossiness",gloss);m.SetFloat("_Metallic",0);EditorUtility.SetDirty(m);return m;
        }
        static Mesh Mesh(List<Vector3> v,List<Vector2> uv,List<int> tr)
        {var mesh=new Mesh();mesh.SetVertices(v);mesh.SetUVs(0,uv);mesh.SetTriangles(tr,0);mesh.RecalculateNormals();mesh.RecalculateTangents();mesh.RecalculateBounds();return mesh;}
        static void SaveMeshAsset(Mesh mesh,string path)
        {var old=AssetDatabase.LoadAssetAtPath<Mesh>(path);if(old==null)AssetDatabase.CreateAsset(mesh,path);else{EditorUtility.CopySerialized(mesh,old);EditorUtility.SetDirty(old);AssetDatabase.SaveAssetIfDirty(old);Object.DestroyImmediate(mesh);}}
        static void Tri(List<int> tr,int a,int b,int c){tr.Add(a);tr.Add(b);tr.Add(c);}
        static void Quad(List<int> tr,int a,int b,int c,int d){Tri(tr,a,b,c);Tri(tr,c,b,d);}
        static Transform Joint(Transform p,string name,Vector3 at){var t=new GameObject(name).transform;t.SetParent(p,false);t.localPosition=at;return t;}
        static GameObject Part(Transform p,string name,Mesh mesh,Material material)
        {var go=new GameObject(name,typeof(MeshFilter),typeof(MeshRenderer));go.transform.SetParent(p,false);go.GetComponent<MeshFilter>().sharedMesh=mesh;go.GetComponent<MeshRenderer>().sharedMaterial=material;go.GetComponent<MeshRenderer>().shadowCastingMode=ShadowCastingMode.Off;return go;}
        static void Ball(Transform p,string name,Vector3 at,Vector3 scale,Material material,Quaternion? rotation=null)
        {var go=Part(p,name,sphere,material);go.transform.localPosition=at;go.transform.localScale=scale;go.transform.localRotation=rotation??Quaternion.identity;}
        static void Bake(Transform parent)
        {
            var groups=new Dictionary<Material,List<CombineInstance>>();var originals=new List<GameObject>();
            foreach(Transform t in parent)
            {
                var mf=t.GetComponent<MeshFilter>();if(mf==null)continue;var mat=t.GetComponent<MeshRenderer>().sharedMaterial;
                if(!groups.ContainsKey(mat))groups[mat]=new List<CombineInstance>();
                groups[mat].Add(new CombineInstance{mesh=mf.sharedMesh,transform=parent.worldToLocalMatrix*t.localToWorldMatrix});originals.Add(t.gameObject);
            }
            foreach(var pair in groups)
            {
                var mesh=new Mesh{name=parent.name+" "+pair.Key.name};mesh.CombineMeshes(pair.Value.ToArray(),true,true);string path=folder+"/Mesh"+(meshId++)+".asset";
                SaveMeshAsset(mesh,path);Part(parent,pair.Key.name,AssetDatabase.LoadAssetAtPath<Mesh>(path),pair.Key);
            }
            foreach(var go in originals){var mesh=go.GetComponent<MeshFilter>().sharedMesh;Object.DestroyImmediate(go);if(!AssetDatabase.Contains(mesh))Object.DestroyImmediate(mesh);}
        }
        public static void RenderGallery()
        {
            Directory.CreateDirectory("ArtPreviews/ReferenceFishCollection");
            for(int i=0;i<Names.Length;i++)Render(Names[i]);
        }
        static void Render(string name)
        {
            var scene=EditorSceneManager.NewPreviewScene();var previous=RenderTexture.active;var target=new RenderTexture(1500,600,24);Texture2D image=null;
            try
            {
                var model=Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Resources/OpenSea/Fish/"+name+".prefab"));SceneManager.MoveGameObjectToScene(model,scene);model.GetComponent<GoldenReferenceFishMotion>().enabled=false;
                var cameraObject=new GameObject("Preview",typeof(Camera));SceneManager.MoveGameObjectToScene(cameraObject,scene);var cam=cameraObject.GetComponent<Camera>();cam.scene=scene;cam.targetTexture=target;cam.orthographic=true;cam.orthographicSize=1.62f;cam.backgroundColor=new Color(.055f,.14f,.21f);cam.clearFlags=CameraClearFlags.SolidColor;
                var key=new GameObject("Key",typeof(Light));SceneManager.MoveGameObjectToScene(key,scene);key.GetComponent<Light>().type=LightType.Directional;key.GetComponent<Light>().intensity=1.25f;
                var fill=new GameObject("Fill",typeof(Light));SceneManager.MoveGameObjectToScene(fill,scene);fill.GetComponent<Light>().type=LightType.Directional;fill.GetComponent<Light>().intensity=.65f;
                Vector3[] views={new Vector3(5,.2f,0),new Vector3(3,1.4f,5),new Vector3(0,5,0)};
                for(int i=0;i<3;i++){cam.rect=new Rect(i/3f,0,1/3f,1);cam.transform.position=views[i];cam.transform.LookAt(Vector3.zero,i==2?Vector3.left:Vector3.up);key.transform.rotation=cam.transform.rotation*Quaternion.Euler(25,-35,0);fill.transform.rotation=cam.transform.rotation*Quaternion.Euler(-25,130,0);cam.Render();}
                RenderTexture.active=target;image=new Texture2D(1500,600,TextureFormat.RGB24,false);image.ReadPixels(new Rect(0,0,1500,600),0,0);image.Apply();File.WriteAllBytes("ArtPreviews/ReferenceFishCollection/"+name+".png",image.EncodeToPNG());
            }
            finally{RenderTexture.active=previous;if(image!=null)Object.DestroyImmediate(image);EditorSceneManager.ClosePreviewScene(scene);Object.DestroyImmediate(target);}
        }
    }
}
