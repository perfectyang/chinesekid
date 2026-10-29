using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Chinsekid.FishGame.Editor
{
    // Create derived meshes. Source FBX, UV seams, material slots and rigs stay intact.
    static class SmoothFishMeshSetup
    {
        sealed class Edge
        {
            public int a, b;
            public readonly List<int> opposite = new();
        }

        public static void Apply(GameObject instance, string species)
        {
            string folder = "Assets/Art/SmoothFish/" + species;
            Directory.CreateDirectory(folder);
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            var cache = new Dictionary<Mesh, Mesh>();
            int index = 0;
            foreach (var renderer in instance.GetComponentsInChildren<Renderer>(true))
            {
                var skin = renderer as SkinnedMeshRenderer;
                var filter = renderer.GetComponent<MeshFilter>();
                var source = skin != null ? skin.sharedMesh : filter != null ? filter.sharedMesh : null;
                if (source == null) continue;
                if (!cache.TryGetValue(source, out var smooth))
                {
                    smooth = Refine(source);
                    string path = folder + "/Mesh" + index++ + ".asset";
                    var existing = AssetDatabase.LoadAssetAtPath<Mesh>(path);
                    if (existing == null) AssetDatabase.CreateAsset(smooth, path);
                    else
                    {
                        EditorUtility.CopySerialized(smooth, existing);
                        UnityEngine.Object.DestroyImmediate(smooth);
                        EditorUtility.SetDirty(existing);
                        smooth = existing;
                    }
                    cache[source] = smooth;
                    Debug.Log("[SmoothFish] " + species + " " + source.vertexCount + " -> " + smooth.vertexCount + " vertices; " + source.bindposes.Length + " bindposes retained.");
                }
                if (skin != null) { skin.sharedMesh = smooth; skin.localBounds = smooth.bounds; }
                else filter.sharedMesh = smooth;
            }
        }

        static long Key(int a, int b) => ((long)Math.Min(a,b) << 32) | (uint)Math.Max(a,b);

        static Mesh Refine(Mesh source)
        {
            if (source.blendShapeCount > 0) throw new InvalidOperationException("Blendshape fish requires explicit delta subdivision: " + source.name);
            var original = source.vertices;
            var vertices = original.ToList();
            var sourceUV = source.uv;
            var uv = (sourceUV.Length == original.Length ? sourceUV : new Vector2[original.Length]).ToList();
            var weights = source.boneWeights.ToList();
            bool skinned = weights.Count == original.Length;
            var sourceColors = source.colors;
            bool colored = sourceColors.Length == original.Length;
            var colors = colored ? sourceColors.ToList() : new List<Color>();
            float tolerance = Mathf.Max(source.bounds.size.magnitude * .000001f, .0000001f);
            var groups = new Dictionary<Vector3Int,int>();
            var points = new List<Vector3>();
            var canonical = new int[original.Length];
            for(int i=0;i<original.Length;i++)
            {
                var p=original[i];
                var key=new Vector3Int(Mathf.RoundToInt(p.x/tolerance),Mathf.RoundToInt(p.y/tolerance),Mathf.RoundToInt(p.z/tolerance));
                if(!groups.TryGetValue(key,out int id)){id=points.Count;groups[key]=id;points.Add(p);}
                canonical[i]=id;
            }
            var edges=new Dictionary<long,Edge>();
            var neighbors=points.Select(_=>new HashSet<int>()).ToArray();
            var triangles=new int[source.subMeshCount][];
            for(int sub=0;sub<triangles.Length;sub++)
            {
                if(source.GetTopology(sub)!=MeshTopology.Triangles)throw new InvalidOperationException("Expected fish triangles: "+source.name);
                triangles[sub]=source.GetTriangles(sub);
                var t=triangles[sub];
                for(int i=0;i<t.Length;i+=3)
                {
                    AddEdge(canonical[t[i]],canonical[t[i+1]],canonical[t[i+2]]);
                    AddEdge(canonical[t[i+1]],canonical[t[i+2]],canonical[t[i]]);
                    AddEdge(canonical[t[i+2]],canonical[t[i]],canonical[t[i+1]]);
                }
            }
            void AddEdge(int a,int b,int opposite)
            {
                if(a==b)return;
                long key=Key(a,b);
                if(!edges.TryGetValue(key,out var edge)){edge=new Edge{a=a,b=b};edges[key]=edge;}
                edge.opposite.Add(opposite);neighbors[a].Add(b);neighbors[b].Add(a);
            }
            var boundary=new bool[points.Count];
            foreach(var edge in edges.Values)if(edge.opposite.Count!=2){boundary[edge.a]=true;boundary[edge.b]=true;}
            var smoothPositions=new Vector3[points.Count];
            for(int i=0;i<points.Count;i++)
            {
                int n=neighbors[i].Count;
                if(boundary[i]||n<3){smoothPositions[i]=points[i];continue;}
                float beta=n==3?3f/16:3f/(8*n);
                Vector3 at=points[i]*(1-n*beta);
                foreach(int neighbor in neighbors[i])at+=points[neighbor]*beta;
                smoothPositions[i]=Vector3.Lerp(points[i],at,.85f);
            }
            for(int i=0;i<original.Length;i++)vertices[i]=smoothPositions[canonical[i]];
            var midpoints=new Dictionary<long,int>();
            int Midpoint(int a,int b)
            {
                long key=Key(a,b);
                if(midpoints.TryGetValue(key,out int found))return found;
                var edge=edges[Key(canonical[a],canonical[b])];
                Vector3 at=(original[a]+original[b])*.5f;
                if(edge.opposite.Count==2)
                    at=Vector3.Lerp(at,(points[edge.a]+points[edge.b])*.375f+(points[edge.opposite[0]]+points[edge.opposite[1]])*.125f,.85f);
                int id=vertices.Count;midpoints[key]=id;vertices.Add(at);uv.Add((uv[a]+uv[b])*.5f);
                if(skinned)weights.Add(BlendWeights(weights[a],weights[b]));
                if(colored)colors.Add((colors[a]+colors[b])*.5f);
                return id;
            }
            var refined=new List<int>[triangles.Length];
            for(int sub=0;sub<triangles.Length;sub++)
            {
                var result=refined[sub]=new List<int>(triangles[sub].Length*4);var t=triangles[sub];
                for(int i=0;i<t.Length;i+=3)
                {
                    int a=t[i],b=t[i+1],c=t[i+2];
                    if(canonical[a]==canonical[b]||canonical[b]==canonical[c]||canonical[c]==canonical[a])continue;
                    int ab=Midpoint(a,b),bc=Midpoint(b,c),ca=Midpoint(c,a);
                    result.AddRange(new[]{a,ab,ca,ab,b,bc,ca,bc,c,ab,bc,ca});
                }
            }
            var mesh=new Mesh{name=source.name+" Rounded"};
            mesh.indexFormat=vertices.Count>65535?IndexFormat.UInt32:IndexFormat.UInt16;
            mesh.SetVertices(vertices);mesh.SetUVs(0,uv);mesh.subMeshCount=refined.Length;
            for(int sub=0;sub<refined.Length;sub++)mesh.SetTriangles(refined[sub],sub);
            if(skinned){mesh.boneWeights=weights.ToArray();mesh.bindposes=source.bindposes;}
            if(colored)mesh.SetColors(colors);
            mesh.RecalculateNormals();
            // Smooth lighting across duplicated UV/material vertices without merging
            // opposite sides of thin fins or eyes with the surrounding body.
            var normals=mesh.normals;
            var normalGroups=new Dictionary<Vector3Int,List<int>>();
            for(int i=0;i<vertices.Count;i++)
            {
                var p=vertices[i];var key=new Vector3Int(Mathf.RoundToInt(p.x/tolerance),Mathf.RoundToInt(p.y/tolerance),Mathf.RoundToInt(p.z/tolerance));
                if(!normalGroups.TryGetValue(key,out var list)){list=new List<int>();normalGroups[key]=list;}list.Add(i);
            }
            var smoothNormals=(Vector3[])normals.Clone();
            foreach(var list in normalGroups.Values)foreach(int i in list)
            {
                Vector3 sum=Vector3.zero;
                foreach(int j in list)if(Vector3.Dot(normals[i],normals[j])>.2f)sum+=normals[j];
                if(sum.sqrMagnitude>.000001f)smoothNormals[i]=sum.normalized;
            }
            mesh.normals=smoothNormals;mesh.RecalculateTangents();mesh.RecalculateBounds();
            return mesh;
        }

        static BoneWeight BlendWeights(BoneWeight a,BoneWeight b)
        {
            var contributions=new Dictionary<int,float>();
            void Add(int bone,float weight){if(weight>0)contributions[bone]=contributions.TryGetValue(bone,out float old)?old+weight*.5f:weight*.5f;}
            Add(a.boneIndex0,a.weight0);Add(a.boneIndex1,a.weight1);Add(a.boneIndex2,a.weight2);Add(a.boneIndex3,a.weight3);
            Add(b.boneIndex0,b.weight0);Add(b.boneIndex1,b.weight1);Add(b.boneIndex2,b.weight2);Add(b.boneIndex3,b.weight3);
            var sorted=contributions.OrderByDescending(pair=>pair.Value).Take(4).ToArray();
            float total=sorted.Sum(pair=>pair.Value);
            var result=new BoneWeight();
            if(total<=0)return result;
            if(sorted.Length>0){result.boneIndex0=sorted[0].Key;result.weight0=sorted[0].Value/total;}
            if(sorted.Length>1){result.boneIndex1=sorted[1].Key;result.weight1=sorted[1].Value/total;}
            if(sorted.Length>2){result.boneIndex2=sorted[2].Key;result.weight2=sorted[2].Value/total;}
            if(sorted.Length>3){result.boneIndex3=sorted[3].Key;result.weight3=sorted[3].Value/total;}
            return result;
        }
    }
}
