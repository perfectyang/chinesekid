using UnityEngine;
using UnityEngine.Rendering;

namespace Chinsekid.FishGame
{
    // A small reusable effect pool keeps eating feedback cheap during busy swims.
    public sealed class FishGameFeedback : MonoBehaviour
    {
        sealed class Ripple { public Transform root; public LineRenderer line; public float age, duration, radius; public Color color; }
        readonly Ripple[] ripples = new Ripple[8];
        Material material;
        Material sparkleMaterial;
        Texture2D sparkleTexture;
        ParticleSystem sparkles;
        ParticleSystem wake;
        float wakeTimer;
        Vector3 lastWakeForward;
        AudioSource sound;
        AudioClip bite, food, levelUp, nearMiss;
        int next;
        float lastBite = -1;
        float lastFood = -1;

        public void Initialize()
        {
            material = new Material(Shader.Find("Sprites/Default"));
            CreateSparkles();
            CreateWake();
            sound = gameObject.AddComponent<AudioSource>();
            sound.playOnAwake = false; sound.spatialBlend = 0; sound.volume = .7f;
            bite = Tone(false); food = Tone(false, true); levelUp = Tone(true); nearMiss = NearMissTone();
            for (int i = 0; i < ripples.Length; i++)
            {
                var root = new GameObject("Soft water ripple"); root.transform.SetParent(transform, false);
                var line = root.AddComponent<LineRenderer>();
                line.sharedMaterial = material; line.useWorldSpace = false; line.loop = true;
                line.positionCount = 48; line.shadowCastingMode = ShadowCastingMode.Off; line.receiveShadows = false;
                for (int p = 0; p < 48; p++)
                {
                    float angle = p * Mathf.PI * 2 / 48;
                    line.SetPosition(p, new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle)));
                }
                root.SetActive(false);
                ripples[i] = new Ripple { root = root.transform, line = line };
            }
        }

        public void Eat(Vector3 at, float size)
        {
            Emit(at, size * 1.1f, .42f, new Color(.72f, 1, .94f, .65f));
            Sparkle(at, new Color(.72f, 1f, .94f, .85f), 10, .075f);
            if (Time.unscaledTime - lastBite > .12f)
            { sound.PlayOneShot(bite, .85f); lastBite = Time.unscaledTime; }
        }
        public void DropMeat(Vector3 at)
        {
            Emit(at, .65f, .4f, new Color(1f, .70f, .43f, .72f));
            Sparkle(at + Vector3.up * .15f, new Color(1f, .80f, .52f, .9f), 6, .07f);
        }
        public void CollectFood()
        {
            if (Time.unscaledTime - lastFood > .09f)
            { sound.PlayOneShot(food, .7f); lastFood = Time.unscaledTime; }
        }
        public void LevelUp(Vector3 at, float size)
        {
            Emit(at, size * 2.1f, .85f, new Color(1, .87f, .48f, .85f));
            Emit(at, size * 1.5f, .6f, new Color(.85f, 1, .94f, .75f));
            Sparkle(at, new Color(1f, .83f, .38f, .95f), 28, .12f);
            sound.PlayOneShot(levelUp);
        }
        public void ChaseWarning(Vector3 at, float size)
        {
            Emit(at, size * 1.55f, .55f, new Color(1f, .72f, .38f, .62f));
        }
        public void NearMiss(Vector3 at, float size)
        {
            Emit(at, size * 1.25f, .4f, new Color(.83f, .96f, 1f, .48f));
            sound.PlayOneShot(nearMiss, .28f);
        }
        public void TouchWater(Vector3 at)
        {
            Emit(at, .52f, .32f, new Color(.67f, .95f, 1f, .42f));
        }
        void CreateSparkles()
        {
            sparkleTexture = new Texture2D(24, 24, TextureFormat.RGBA32, false) { name = "Soft fish sparkle" };
            var pixels = new Color[24 * 24];
            for (int y = 0; y < 24; y++)
                for (int x = 0; x < 24; x++)
                {
                    float radius = new Vector2((x - 11.5f) / 11.5f, (y - 11.5f) / 11.5f).magnitude;
                    pixels[y * 24 + x] = new Color(1f, 1f, 1f, Mathf.Pow(Mathf.Clamp01(1f - radius), 1.6f));
                }
            sparkleTexture.SetPixels(pixels);
            sparkleTexture.Apply();
            sparkleMaterial = new Material(Shader.Find("Sprites/Default")) { mainTexture = sparkleTexture };
            var root = new GameObject("Eating and growth sparkles");
            root.transform.SetParent(transform, false);
            sparkles = root.AddComponent<ParticleSystem>();
            var main = sparkles.main;
            main.loop = true;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.startLifetime = .55f;
            main.startSpeed = 1.3f;
            main.maxParticles = 96;
            var emission = sparkles.emission;
            emission.rateOverTime = 0f;
            var shape = sparkles.shape;
            shape.shapeType = ParticleSystemShapeType.Sphere;
            shape.radius = .18f;
            var renderer = root.GetComponent<ParticleSystemRenderer>();
            renderer.sharedMaterial = sparkleMaterial;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            sparkles.Play();
        }
        void CreateWake()
        {
            var root = new GameObject("Player turning wake");
            root.transform.SetParent(transform, false);
            wake = root.AddComponent<ParticleSystem>();
            var main = wake.main;
            main.loop = true;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.startLifetime = .42f;
            main.startSpeed = 0f;
            main.maxParticles = 24;
            var emission = wake.emission;
            emission.rateOverTime = 0f;
            var shape = wake.shape;
            shape.enabled = false;
            var renderer = root.GetComponent<ParticleSystemRenderer>();
            renderer.sharedMaterial = sparkleMaterial;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            wake.Play();
        }
        public void UpdateWake(FishActor player, float dt, bool steering)
        {
            if (wake == null || player == null) return;
            Vector3 forward = player.transform.forward;
            Vector3 previousForward = lastWakeForward;
            float turn = previousForward.sqrMagnitude < .5f ? 0f : Vector3.Angle(previousForward, forward);
            lastWakeForward = forward;
            if (!steering || player.Velocity.sqrMagnitude < .5f) { wakeTimer = 0f; return; }
            wakeTimer += dt;
            float interval = turn > 1.5f ? .07f : .12f;
            if (wakeTimer < interval) return;
            wakeTimer = 0f;
            Vector3 side = player.transform.right * Mathf.Clamp(turn * .016f, 0f, .12f) *
                (Vector3.Cross(previousForward, forward).y >= 0 ? 1f : -1f);
            wake.transform.position = player.transform.position - forward * (player.Size * .9f) + side;
            wake.Emit(new ParticleSystem.EmitParams
            {
                startColor = new Color(.72f, .96f, 1f, turn > 1.5f ? .35f : .22f),
                startSize = turn > 1.5f ? .12f : .08f,
                velocity = -forward * .22f
            }, 1);
        }
        void Sparkle(Vector3 at, Color color, int count, float size)
        {
            sparkles.transform.position = at;
            sparkles.Emit(new ParticleSystem.EmitParams { startColor = color, startSize = size }, count);
        }
        void Emit(Vector3 at, float radius, float duration, Color color)
        {
            var ripple = ripples[next++ % ripples.Length];
            ripple.root.gameObject.SetActive(true); ripple.root.position = at + Vector3.down * .12f;
            ripple.age = 0; ripple.duration = duration; ripple.radius = radius; ripple.color = color;
            Apply(ripple);
        }
        void Update()
        {
            foreach (var ripple in ripples)
            {
                if (ripple == null || !ripple.root.gameObject.activeSelf) continue;
                ripple.age += Time.deltaTime;
                if (ripple.age >= ripple.duration) ripple.root.gameObject.SetActive(false);
                else Apply(ripple);
            }
        }
        static void Apply(Ripple ripple)
        {
            float t = ripple.age / ripple.duration;
            ripple.root.localScale = Vector3.one * Mathf.Lerp(.18f, ripple.radius, 1 - (1 - t) * (1 - t));
            var color = ripple.color; color.a *= (1 - t) * (1 - t);
            ripple.line.startColor = ripple.line.endColor = color;
            ripple.line.startWidth = ripple.line.endWidth = Mathf.Lerp(.045f, .008f, t);
        }
        public void ShiftOrigin(Vector3 offset)
        {
            foreach (var ripple in ripples) if (ripple != null) ripple.root.position -= offset;
            if (sparkles != null) sparkles.Clear();
            if (wake != null) wake.Clear();
        }

        static AudioClip Tone(bool upgrade, bool foodTone = false)
        {
            const int rate = 24000;
            float duration = upgrade ? .58f : foodTone ? .1f : .12f;
            var samples = new float[Mathf.CeilToInt(duration * rate)];
            float phase = 0;
            float[] notes = { 659.25f, 830.61f, 987.77f };
            for (int i = 0; i < samples.Length; i++)
            {
                float time = i / (float)rate;
                int note = Mathf.Min(2, (int)(time / .15f));
                float local = upgrade ? time - note * .15f : time;
                float frequency = upgrade ? notes[note] : foodTone
                    ? Mathf.Lerp(950, 680, time / duration)
                    : Mathf.Lerp(620, 340, time / duration);
                phase += frequency * Mathf.PI * 2 / rate;
                float envelope = Mathf.Min(1, local / .009f) * Mathf.Exp(-local * (upgrade ? 11 : 35));
                float fade = Mathf.Clamp01((duration - time) / .045f);
                samples[i] = (Mathf.Sin(phase) + .16f * Mathf.Sin(phase * 2)) * envelope * fade * .38f;
            }
            var clip = AudioClip.Create(upgrade ? "Growth chime" : foodTone ? "Food plink" : "Bubble bite", samples.Length, 1, rate, false);
            clip.SetData(samples, 0); return clip;
        }
        static AudioClip NearMissTone()
        {
            const int rate = 24000;
            var samples = new float[2880];
            float phase = 0;
            for (int i = 0; i < samples.Length; i++)
            {
                float t = i / (float)samples.Length;
                phase += Mathf.Lerp(510f, 380f, t) * Mathf.PI * 2f / rate;
                samples[i] = Mathf.Sin(phase) * Mathf.Sin(t * Mathf.PI) * .14f;
            }
            var clip = AudioClip.Create("Close swim", samples.Length, 1, rate, false);
            clip.SetData(samples, 0);
            return clip;
        }
        void OnDestroy()
        {
            if (material != null) Destroy(material);
            if (sparkleMaterial != null) Destroy(sparkleMaterial);
            if (sparkleTexture != null) Destroy(sparkleTexture);
            if (bite != null) Destroy(bite);
            if (food != null) Destroy(food);
            if (levelUp != null) Destroy(levelUp);
            if (nearMiss != null) Destroy(nearMiss);
        }
    }
}
