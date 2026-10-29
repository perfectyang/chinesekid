using System;
using UnityEngine;
namespace Chinsekid.FishGame.Editor
{
    public static class FishBodySizingSetup
    {
        public static void Validate()
        {
            float previous = FishActor.GrowthScale(1);
            for (int level=2;level<=1000;level++)
            {
                float size=FishActor.GrowthScale(level);
                if(size<previous || size / previous > 1.033f || size > .7426f)
                    throw new InvalidOperationException("Abrupt or unbounded body growth at " + level);
                previous=size;
            }
            float screen1 = FishActor.GrowthScale(1) / FishGameManager.CameraDistanceScale(FishActor.GrowthScale(1));
            float screen5 = FishActor.GrowthScale(5) / FishGameManager.CameraDistanceScale(FishActor.GrowthScale(5));
            if(screen5/screen1 < 1.10f || screen5/screen1 > 1.13f)
                throw new InvalidOperationException("Early visible growth should be gradual");
            if(FishGameManager.FishReward(115,115)>14 || FishGameManager.FishReward(1,1)!=FishGameManager.FishReward(115,115))
                throw new InvalidOperationException("High-level rewards accelerate leveling");
            string[] models = {"Clownfish","BlueTang","ButterflyFish","CoralGrouper","Goldfish","Koi","Puffer","RoyalGramma","Tang","GoldenReference","PatternedReef","RubyLionfish","SpottedPuffer","AzureAngelfish","Shark","Anglerfish","Lionfish","FangHunter","GrinningShark","IridescentShark"};
            foreach (string model in models)
            {
                var root = new GameObject("Sizing " + model);
                var actor = root.AddComponent<FishActor>();
                actor.Configure(1, SeaCreatureKind.Fish, Color.white, false, model);
                var visual = root.GetComponentInChildren<OpenSeaFishVisual>();
                Bounds core = OpenSeaFishVisual.MeasureBody(visual.gameObject);
                float area = OpenSeaFishVisual.ProjectedBodyArea(core.size) * visual.transform.localScale.x * visual.transform.localScale.x;
                if(Mathf.Abs(area - 1.05f) > .002f) throw new InvalidOperationException("Unequal body footprint: " + model + " " + area);
                actor.SetLevel(10); actor.SetLevel(1);
                if(Mathf.Abs(actor.Size - .45f) > .001f) throw new InvalidOperationException("Recycled fish has stale level size");
                Debug.Log("[FishSizingCheck] " + model + " bodyArea=" + area);
                UnityEngine.Object.DestroyImmediate(root);
            }
            EndlessSeaValidation.Run();
            if(GameObject.Find("BOOST BUTTON") != null)
                throw new InvalidOperationException("Manual boost remains visible");
            Debug.Log("[FishSizingCheck] PASS: growth anchors, cap, removed boost, endless population and camera.");
        }
    }
}
