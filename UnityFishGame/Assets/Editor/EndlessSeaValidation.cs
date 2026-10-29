using System;
using System.Collections.Generic;
using System.Reflection;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UI;

namespace Chinsekid.FishGame.Editor
{
    public static class EndlessSeaValidation
    {
        const BindingFlags PrivateInstance = BindingFlags.NonPublic | BindingFlags.Instance;
        static T Field<T>(object owner, string name) => (T)owner.GetType().GetField(name, PrivateInstance).GetValue(owner);
        static void Call(object owner, string name, params object[] args) => owner.GetType().GetMethod(name, PrivateInstance).Invoke(owner, args);
        static void Check(bool value, string message) { if (!value) throw new InvalidOperationException(message); }

        public static void Run()
        {
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var manager = new GameObject("Endless sea validation").AddComponent<FishGameManager>();
            manager.Initialize();
            var player = Field<FishActor>(manager, "player");
            var camera = Field<Camera>(manager, "gameCamera");
            Check(camera.orthographic, "Perspective camera distorts fish sizes by distance");
            var actors = Field<List<FishActor>>(manager, "fish");
            var environment = Field<EndlessSeaWorld>(manager, "endlessSea");
            var floor = Field<Transform>(manager, "oceanFloor");
            var samples = new[] { Vector3.zero, new Vector3(150,0,120), new Vector3(-250,0,-180),
                new Vector3(1800,0,-1600), new Vector3(2400,0,2300) };
            foreach (int level in new[] {1, 10, 115})
            foreach (float aspect in new[] { .75f, 4f/3f })
            {
                player.SetLevel(level);
                player.transform.localScale = Vector3.one * FishActor.GrowthScale(level);
                camera.aspect = aspect;
                foreach (var sample in samples)
                {
                    player.Relocate(new Vector3(sample.x,.2f,sample.z));
                    Call(manager,"UpdateCamera",10f);
                    typeof(FishGameManager).GetMethod("KeepInWorld", BindingFlags.NonPublic | BindingFlags.Static)
                        .Invoke(null,new object[]{player.transform});
                    Check(Mathf.Abs(player.transform.position.x-sample.x)<.001f && Mathf.Abs(player.transform.position.z-sample.z)<.001f,
                        "Player was clamped to the old map boundary");
                    Call(manager,"RebaseWorldIfNeeded");
                    environment.Follow(player.transform.position);
                    for(int iteration=0;iteration<5;iteration++) Call(manager,"MaintainPopulation",true);
                    int visible=0,edible=0,threats=0;
                    foreach(var fish in actors)
                    {
                        var at=camera.WorldToViewportPoint(fish.transform.position);
                        if(at.z<=0 || at.x<=.02f || at.x>=.98f || at.y<=.06f || at.y>=.92f)continue;
                        visible++;if(fish.Level<=player.Level)edible++;else threats++;
                        Check(Vector3.Distance(fish.transform.position,player.transform.position)>2.4f,"Fish spawned on the player");
                    }
                    Check(threats>=4,"Too few visible fish above player level at " + sample + " Lv." + level + ": " + threats);
                    Check(visible>=6 && edible>=5,"Sparse fish population at "+sample+": "+visible+" visible / "+edible+" edible");
                    Check(visible<=11,"Too many visible fish at " + sample + ": " + visible);
                    Check(actors.Count<=48,"Unbounded fish population");
                    Check(Mathf.Abs(player.transform.position.x)<2000 && Mathf.Abs(player.transform.position.z)<2000,"Floating origin did not rebase");
                    foreach(float x in new[]{.01f,.99f})foreach(float y in new[]{.01f,.99f})
                    {
                        var ray=camera.ViewportPointToRay(new Vector3(x,y,0));
                        Check(new Plane(Vector3.up,new Vector3(0,-1.25f,0)).Raycast(ray,out float distance),"Camera sees beyond the seabed");
                        var hit=ray.GetPoint(distance)-floor.position;
                        Check(Mathf.Abs(hit.x)<400 && Mathf.Abs(hit.z)<400,"Seabed edge is visible");
                    }
                    Debug.Log("[EndlessSeaCheck] level="+level+" aspect="+aspect+" sample="+sample+" visible="+visible+" edible="+edible+" threats="+threats+" total="+actors.Count);
                }
            }
            var overlay = Field<FishLevelOverlay>(manager, "fishLevels");
            overlay.Refresh(camera, player, actors);
            var canvasScaler = overlay.GetComponent<CanvasScaler>();
            Check(canvasScaler.uiScaleMode == CanvasScaler.ScaleMode.ConstantPixelSize && canvasScaler.scaleFactor >= 1.4f, "Fish labels shrink on portrait iPad");
            foreach (var badge in overlay.GetComponentsInChildren<RectTransform>())
                if (badge.gameObject.name == "Fish level badge")
                    Check(badge.GetComponent<Image>() == null, "Fish level text still has a background");
            int otherFishLabels = 0;
            foreach (var label in overlay.GetComponentsInChildren<Text>())
                if (label.text.StartsWith("Lv.") && label.fontSize >= 26 && label.gameObject.activeInHierarchy)
                    otherFishLabels++;
            Check(otherFishLabels >= 5, "Nearby fish level labels are missing or unreadable");
            foreach(var image in UnityEngine.Object.FindObjectsByType<Image>(FindObjectsSortMode.None))
                if(image.gameObject.name=="Growth badge" || image.gameObject.name=="Return to app")
                    Check(image.color.a==0,"HUD panel backdrop is still visible");
            var predator = new GameObject("Chase timing validation").AddComponent<FishActor>();
            predator.Relocate(player.transform.position + Vector3.right * 8f, true);
            bool beganChasing = false;
            for (int i = 0; i < 30; i++) beganChasing |= predator.UpdateChase(player.transform.position, true, .1f);
            Check(beganChasing, "Visible predator did not start chasing promptly");
            bool stoppedChasing = false;
            for (int i = 0; i < 80; i++)
                if (!predator.UpdateChase(player.transform.position, true, .1f)) { stoppedChasing = true; break; }
            Check(stoppedChasing, "Predator never stopped chasing");
            for (int i = 0; i < 30; i++)
                Check(!predator.UpdateChase(player.transform.position, true, .1f), "Predator restarted during its cooldown");
            bool chasedAgain = false;
            for (int i = 0; i < 130; i++) chasedAgain |= predator.UpdateChase(player.transform.position, true, .1f);
            Check(chasedAgain, "Predator never returned after its cooldown");
            UnityEngine.Object.DestroyImmediate(predator.gameObject);
            Debug.Log("[EndlessSeaCheck] PASS: portrait/landscape, old map limits, far travel/rebase, visible edible fish, capped population, seabed coverage and transparent HUD.");
        }
    }
}
