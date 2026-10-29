using System.Collections.Generic;
using UnityEngine;

namespace Chinsekid.FishGame
{
    // Shared low-poly geometry and materials; water and plants animate on the GPU.
    static class ColorfulReefArt
    {
        static readonly Dictionary<string, Mesh> meshes = new();
        static readonly Dictionary<string, Material> materials = new();
        static readonly Color[] CoralColors = {
            new Color(.45f,.40f,.73f), new Color(.93f,.48f,.64f), new Color(.94f,.66f,.42f),
            new Color(.88f,.76f,.48f), new Color(.35f,.72f,.82f), new Color(.39f,.77f,.69f),
            new Color(.78f,.48f,.78f), new Color(.49f,.58f,.85f)
        };
        static readonly Color[] GrassColors = {
            new Color(.20f,.49f,.56f), new Color(.37f,.63f,.54f), new Color(.24f,.57f,.68f),
            new Color(.34f,.54f,.48f), new Color(.28f,.46f,.68f)
        };
        static Material Paint(Color color, bool grass=false)
        {
            string key=ColorUtility.ToHtmlStringRGB(color)+(grass?"grass":"reef");
            if(materials.TryGetValue(key,out var cached)&&cached!=null)return cached;
            var shader=Resources.Load<Shader>("ReefSurface");
            if(shader==null)return SeaArt.Solid(color,.2f);
            var mat=new Material(shader){name="Reef "+key};
            mat.SetColor("_BaseColor",Color.Lerp(color,new Color(.05f,.12f,.30f),.12f));
            mat.SetColor("_TopColor",Color.Lerp(color,grass?new Color(.73f,.94f,.46f):new Color(1,.91f,.85f),grass?.33f:.32f));
            mat.SetFloat("_Sway",grass?1:0);return materials[key]=mat;
        }
        public static void Populate(Transform parent)
        {
            // Jittered colonies keep colorful reefs visible across the map while leaving sandy lanes.
            for(int row=0;row<11;row++)for(int column=0;column<13;column++)
            {
                int index=row*13+column;
                var colony=new GameObject("Colorful reef garden").transform;colony.SetParent(parent,false);
                colony.localPosition=new Vector3(-54+column*9+Random.Range(-1.7f,1.7f),-1.22f,-45+row*9+Random.Range(-1.7f,1.7f));
                colony.localRotation=Quaternion.Euler(0,Random.Range(0,360),0);
                float size=Random.Range(.62f,.88f);
                // Tall forms stay below the swimming layer; plates spread across the seabed.
                var coral=SeaArt.Part("Colored branching coral",colony,SeaArt.Coral(index%4),Paint(CoralColors[index%8]),Vector3.zero,Vector3.one*size*.70f);
                coral.transform.localRotation=Quaternion.Euler(0,index*47,0);
                for(int tube=0;tube<3;tube++)
                    SeaArt.Part("Hollow sponge tube",colony,Sponge(),Paint(CoralColors[(index+3)%8]),
                        new Vector3(1.05f+tube*.32f,0,(tube%2)*.32f),new Vector3(.42f,.65f+tube*.16f,.42f)*size);
                var plate=SeaArt.Part("Scalloped plate coral",colony,Plate(index%3),Paint(CoralColors[(index+1)%8]),new Vector3(-1.05f,.10f,.25f),new Vector3(.92f,.8f,.92f)*size);
                plate.transform.localRotation=Quaternion.Euler(0,index*29,0);
                SeaArt.Part("Layered plate coral",colony,Plate((index+1)%3),Paint(CoralColors[(index+2)%8]),new Vector3(-1.3f,.27f,.12f),new Vector3(.68f,.75f,.68f)*size);
                for(int tuft=0;tuft<2;tuft++)
                    SeaArt.Part("Swaying seagrass",colony,Grass((index+tuft)%3),Paint(GrassColors[(index+tuft)%GrassColors.Length],true),
                        new Vector3(tuft==0?-.30f:1.6f,0,tuft==0?-1.35f:.9f),new Vector3(.85f,.6f,.85f)*size);
                var rockMaterial=Resources.Load<Material>("OpenSea/Environment/ReefRock")??SeaArt.Solid(new Color(.31f,.46f,.48f),.12f);
                for(int rock=0;rock<2;rock++)
                    SeaArt.Part("Reef foundation stone",colony,SeaArt.Pearl(),rockMaterial,new Vector3(rock*.9f-.5f,-.06f,.25f),new Vector3(1.4f,.37f,1.1f)*size);
                SeaArt.CombineDetails(colony);
            }
        }
        public static void Water(Transform parent)
        {
            var shader=Resources.Load<Shader>("ReefWater");if(shader==null)return;
            var water=GameObject.CreatePrimitive(PrimitiveType.Plane);water.name="Moving underwater caustics";
            water.transform.SetParent(parent,false);water.transform.localPosition=new Vector3(0,-1.19f,0);water.transform.localScale=new Vector3(16,1,13);
            Object.Destroy(water.GetComponent<Collider>());
            var renderer=water.GetComponent<Renderer>();renderer.sharedMaterial=new Material(shader);renderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;renderer.receiveShadows=false;
        }
        static Mesh Sponge()
        {
            if(meshes.TryGetValue("sponge",out var mesh)&&mesh!=null)return mesh;
            var v=new List<Vector3>();var uv=new List<Vector2>();var tr=new List<int>();const int sides=16;
            // Outer wall, rolled lip and deep inner wall leave an actual open tube.
            float[] radii={.39f,.45f,.50f,.42f,.32f,.29f};float[] heights={0,.65f,1.02f,1.10f,1.02f,.28f};
            for(int ring=0;ring<radii.Length;ring++)for(int side=0;side<=sides;side++)
            {
                float a=side/(float)sides*Mathf.PI*2;float r=radii[ring]*(1+.045f*Mathf.Sin(a*5));
                v.Add(new Vector3(Mathf.Cos(a)*r,heights[ring],Mathf.Sin(a)*r));uv.Add(new Vector2(side/(float)sides,ring/(float)(radii.Length-1)));
                if(ring<radii.Length-1&&side<sides){int k=ring*(sides+1)+side;Quad(tr,k,k+1,k+sides+1,k+sides+2);}
            }
            return meshes["sponge"]=Make("Rolled open sponge",v,uv,tr);
        }
        static Mesh Plate(int variant)
        {
            string key="plate"+variant;if(meshes.TryGetValue(key,out var mesh)&&mesh!=null)return mesh;
            var v=new List<Vector3>();var uv=new List<Vector2>();var tr=new List<int>();const int rings=10,sides=64;
            for(int ring=0;ring<=rings;ring++)for(int side=0;side<=sides;side++)
            {
                float t=ring/(float)rings,a=side/(float)sides*Mathf.PI*2;
                float r=t*(1+.035f*Mathf.Sin(a*(7+variant)));
                float y=.10f+Mathf.Sin(t*Mathf.PI*.85f)*.22f+Mathf.Sin(a*12)*.012f*t;
                v.Add(new Vector3(Mathf.Cos(a)*r,y,Mathf.Sin(a)*r));uv.Add(new Vector2(side/(float)sides,t));
                if(ring<rings&&side<sides){int k=ring*(sides+1)+side;Quad(tr,k,k+1,k+sides+1,k+sides+2);}
            }
            return meshes[key]=Make("Scalloped coral plate",v,uv,tr);
        }
        static Mesh Grass(int variant)
        {
            string key="grass"+variant;if(meshes.TryGetValue(key,out var mesh)&&mesh!=null)return mesh;
            var v=new List<Vector3>();var uv=new List<Vector2>();var tr=new List<int>();const int steps=9;
            for(int blade=0;blade<7;blade++)
            {
                float angle=blade*2.4f+variant,length=1.1f+(blade%3)*.3f;var outward=new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle));
                var right=Vector3.Cross(Vector3.up,outward);int start=v.Count;
                for(int step=0;step<=steps;step++)
                {
                    float t=step/(float)steps,width=Mathf.Sin(t*Mathf.PI)*.15f+.015f;
                    var center=outward*(.16f+t*t*.55f)+Vector3.up*(t*length);
                    v.Add(center-right*width);v.Add(center+right*width);uv.Add(new Vector2(0,t));uv.Add(new Vector2(1,t));
                    if(step<steps){int k=start+step*2;Quad(tr,k,k+1,k+2,k+3);}
                }
            }
            return meshes[key]=Make("Curving ribbon grass",v,uv,tr);
        }
        static void Quad(List<int> t,int a,int b,int c,int d){t.Add(a);t.Add(b);t.Add(c);t.Add(c);t.Add(b);t.Add(d);}
        static Mesh Make(string name,List<Vector3> v,List<Vector2> uv,List<int> t)
        {var mesh=new Mesh{name=name};mesh.SetVertices(v);mesh.SetUVs(0,uv);mesh.SetTriangles(t,0);mesh.RecalculateNormals();
            if(name=="Scalloped coral plate")
            {
                var normals=mesh.normals;
                for(int ring=0;ring<=10;ring++)
                {int first=ring*65,last=first+64;var normal=(normals[first]+normals[last]).normalized;normals[first]=normals[last]=normal;}
                for(int side=0;side<=64;side++)normals[side]=Vector3.up;
                mesh.normals=normals;
            }
            mesh.RecalculateBounds();mesh.bounds=new Bounds(mesh.bounds.center,mesh.bounds.size+new Vector3(.4f,0,.3f));return mesh;}
    }
}
