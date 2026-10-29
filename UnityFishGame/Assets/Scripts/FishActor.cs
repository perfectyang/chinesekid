using UnityEngine;

namespace Chinsekid.FishGame
{
    public enum SeaCreatureKind { Fish, Shrimp, Octopus }

    public sealed class FishActor : MonoBehaviour
    {
        public int Level { get; private set; }
        public float Size => transform.localScale.x;
        public bool IsPlayer { get; private set; }
        public bool IsHunter { get; set; }
        public SeaCreatureKind Kind { get; private set; }
        public Vector3 Velocity { get; private set; }

        Transform visualRoot;
        Vector3 visualRestPosition;
        Transform tail;
        Transform eyes;
        OpenSeaFishVisual importedVisual;
        Vector3 target;
        float turnSpeed = 210f;
        float swimPhase;
        float speed = 2f;
        float targetScale;
        float biteRemaining;
        public void PlayBite() => biteRemaining = .22f;
        float turnBank;
        float targetBank;
        float chaseRemaining;
        float chaseCooldown;
        float chaseWindup;
        public static float ChaseWindupDuration = .52f;
        public static float ChaseMinDuration = 4f;
        public static float ChaseMaxDuration = 6f;
        public static float ChaseMinCooldown = 8f;
        public static float ChaseMaxCooldown = 12f;
        public bool IsPreparingChase => chaseWindup > 0;
        public bool ChaseWarningStarted { get; private set; }

        public bool UpdateChase(Vector3 playerPosition, bool canChase, float deltaTime)
        {
            ChaseWarningStarted = false;
            if (chaseWindup > 0)
            {
                if (!canChase) { chaseWindup = 0; return false; }
                chaseWindup = Mathf.Max(0, chaseWindup - deltaTime);
                if (chaseWindup > 0) return false;
                chaseRemaining = Random.Range(ChaseMinDuration, ChaseMaxDuration);
                return true;
            }
            if (chaseCooldown > 0)
            {
                chaseCooldown = Mathf.Max(0, chaseCooldown - deltaTime);
                return false;
            }
            if (chaseRemaining > 0)
            {
                chaseRemaining = Mathf.Max(0, chaseRemaining - deltaTime);
                if (canChase && chaseRemaining > 0) return true;
                chaseRemaining = 0;
                chaseCooldown = Random.Range(ChaseMinCooldown, ChaseMaxCooldown);
                Vector3 away = transform.position - playerPosition;
                away.y = 0;
                if (away.sqrMagnitude < .001f) away = transform.forward;
                target = transform.position + away.normalized * 14f;
                return false;
            }
            if (!canChase) return false;
            chaseWindup = ChaseWindupDuration;
            ChaseWarningStarted = true;
            return false;
        }

        public void Configure(int level, SeaCreatureKind kind, Color color, bool player = false, string selectedModel = null)
        {
            Level = Mathf.Max(1, level);
            Kind = kind;
            IsPlayer = player;
            turnSpeed = player ? 900f : 300f;
            BuildModel(color, selectedModel);
            SetLevel(Level);
            SetRoamingTarget();
        }

        void SetRoamingTarget()
        {
            Vector2 heading = Random.insideUnitCircle.normalized;
            target = transform.position + new Vector3(heading.x, 0, heading.y) * 12f;
        }

        public void Relocate(Vector3 position, bool enteringPlayerView = false)
        {
            transform.position = position;
            Velocity = Vector3.zero;
            chaseRemaining = 0;
            chaseWindup = 0;
            chaseCooldown = enteringPlayerView ? Random.Range(1.1f, 2.1f) : Random.Range(ChaseMinCooldown, ChaseMaxCooldown);
            SetRoamingTarget();
        }

        public void ShiftOrigin(Vector3 offset)
        {
            transform.position -= offset;
            target -= offset;
        }

        public void SetLevel(int level)
        {
            Level = Mathf.Max(1, level);
            competitorGrowth = 0;
            // Same curve for everyone: a level-one player must not dwarf level-two prey.
            // Growth is capped at 1.65 times the initial body size.
            SetGrowthProgress(0);
            if (!IsPlayer || transform.localScale.sqrMagnitude < 0.001f || transform.localScale == Vector3.one)
                transform.localScale = Vector3.one * targetScale;
            speed = IsPlayer ? Mathf.Min(7.4f, 3.6f + (Level - 1) * 0.14f) : Mathf.Clamp(2.2f + Level * 0.15f, 2.1f, 4.4f);
        }

        public void SetGrowthProgress(float progress)
        {
            // Fractional growth stays below the next level's size until the actual level-up.
            float growthLevel = Level - 1 + Mathf.Clamp(progress, 0, .99f);
            targetScale = GrowthScale(growthLevel + 1);
        }

        // Small gains per level, then a gentle plateau at 1.65x the initial body.
        public static float GrowthScale(float level)
        {
            float ratio = 1 + .65f * (1 - Mathf.Exp(-Mathf.Max(0, level - 1) / 20f));
            return .45f * ratio;
        }

        int competitorGrowth;
        public void GainGrowthPoints(int points)
        {
            competitorGrowth += points;
            if (competitorGrowth >= 91)
            {
                int remaining = competitorGrowth % 91;
                SetLevel(Level + competitorGrowth / 91);
                competitorGrowth = remaining;
            }
            SetGrowthProgress(competitorGrowth / 91f);
        }

        public void SetTarget(Vector3 worldTarget) => target = worldTarget;

        public void SwimToward(Vector3 worldTarget, float deltaTime, float speedMultiplier = 1f)
        {
            Vector3 flat = worldTarget - transform.position;
            flat.y = 0;
            if (flat.sqrMagnitude < 0.0064f)
            {
                Velocity = Vector3.zero;
                targetBank = 0;
                AnimateBody(deltaTime, speedMultiplier);
                return;
            }
            Vector3 desired = flat.normalized;
            // Signed angles cross 0/360 continuously, including full circles and U-turns.
            float angle = Vector3.SignedAngle(transform.forward, desired, Vector3.up);
            float turn = Mathf.Clamp(angle * (1f - Mathf.Exp(-(IsPlayer ? 22f : 10f) * deltaTime)),
                -turnSpeed * deltaTime, turnSpeed * deltaTime);
            transform.rotation = Quaternion.AngleAxis(turn, Vector3.up) * transform.rotation;
            targetBank = Mathf.Clamp(-turn / Mathf.Max(deltaTime, .0001f) * .025f, -18f, 18f);

            // Steer velocity with the head so old momentum cannot keep pushing
            // the player in the previous direction after a finger direction change.
            float alignment = Mathf.Clamp01(Vector3.Dot(transform.forward, desired));
            float desiredSpeed = speed * speedMultiplier * Mathf.Lerp(.35f, 1f, alignment);
            float swimSpeed = Mathf.Lerp(Velocity.magnitude, desiredSpeed,
                1f - Mathf.Exp(-(IsPlayer ? 18f : 8f) * deltaTime));
            float step = Mathf.Min(swimSpeed * deltaTime, flat.magnitude);
            Velocity = transform.forward * (step / Mathf.Max(deltaTime, .0001f));
            transform.position += transform.forward * step;
            AnimateBody(deltaTime, speedMultiplier);
        }

        public void Wander(float deltaTime)
        {
            if ((target - transform.position).sqrMagnitude < 9f)
            {
                target = transform.position + new Vector3(Random.Range(-12f, 12f), 0, Random.Range(-10f, 10f));
            }
            SwimToward(target, deltaTime);
        }

        void BuildModel(Color color, string selectedModel)
        {
            if (Kind == SeaCreatureKind.Fish)
            {
                visualRoot = OpenSeaFishVisual.Create(transform, Level, selectedModel, IsPlayer);
                if (visualRoot != null)
                {
                    visualRestPosition = visualRoot.localPosition;
                    importedVisual = visualRoot.GetComponent<OpenSeaFishVisual>();
                    swimPhase = Random.value * Mathf.PI * 2;
                    return;
                }
            }
            visualRoot = new GameObject("Sculpted sea creature").transform;
            visualRoot.SetParent(transform, false);
            swimPhase = Random.value * Mathf.PI * 2f;
            int pattern = IsPlayer ? 0 : Mathf.Abs(Mathf.RoundToInt((color.r + color.g * 2f + color.b * 3f) * 11f)) % 3;
            Material main = SeaArt.Painted(color, pattern);
            Material fin = SeaArt.Painted(Color.Lerp(color, new Color(1f, .84f, .53f), .28f), pattern, true);
            Material belly = SeaArt.Painted(Color.Lerp(color, Color.white, .55f), 2);
            Material dark = Solid(Color.Lerp(color, new Color(.02f, .10f, .18f), .7f), .3f);

            if (Kind == SeaCreatureKind.Fish)
            {
                SeaArt.Part("Continuous patterned body", visualRoot, SeaArt.FishBody(), main, Vector3.zero, Vector3.one);
                tail = new GameObject("Tail joint").transform;
                tail.SetParent(visualRoot, false);
                tail.localPosition = new Vector3(0, 0, -.94f);
                SeaArt.Part("Scalloped fan tail", tail, SeaArt.Fin(true), fin, Vector3.zero, new Vector3(1, 1, .75f));
                AddFin(visualRoot, new Vector3(-.40f, -.03f, .05f), new Vector3(.7f, 1, .75f), fin, -70);
                AddFin(visualRoot, new Vector3(.40f, -.03f, .05f), new Vector3(.7f, 1, .75f), fin, 70);
                var dorsal = SeaArt.Part("Swept dorsal fin", visualRoot, SeaArt.Fin(false), fin,
                    new Vector3(0, .29f, .12f), new Vector3(.90f, 1, .70f));
                dorsal.transform.localRotation = Quaternion.Euler(0, 0, 90);
                AddEyes(new Vector3(-.32f, .23f, .66f), new Vector3(.32f, .23f, .66f), .24f, dark);
                AddSphere("Small smiling mouth", visualRoot, new Vector3(0, .015f, .995f), new Vector3(.15f, .055f, .035f), dark);
            }
            else if (Kind == SeaCreatureKind.Shrimp)
            {
                for (int i = 0; i < 6; i++)
                {
                    float t = i / 5f;
                    var segment = SeaArt.Part("Curved shell plate", visualRoot, SeaArt.FishBody(), i % 2 == 0 ? main : belly,
                        new Vector3(0, Mathf.Sin(t * Mathf.PI) * .18f, .48f - t * 1.3f), new Vector3(.5f - t * .22f, .68f - t * .3f, .25f));
                    segment.transform.localRotation = Quaternion.Euler(t * -22f, 0, 0);
                }
                tail = new GameObject("Shrimp tail joint").transform;
                tail.SetParent(visualRoot, false);
                tail.localPosition = new Vector3(0, .05f, -.9f);
                SeaArt.Part("Shrimp tail fan", tail, SeaArt.Fin(true), fin, Vector3.zero, new Vector3(.63f, 1, .4f));
                for (int side = -1; side <= 1; side += 2)
                {
                    SeaArt.Part("Long antenna", visualRoot, SeaArt.Feeler(), fin,
                        new Vector3(side * .13f, .12f, .66f), Vector3.one).transform.localRotation = Quaternion.Euler(0, side * 20f, 0);
                    for (int i = 0; i < 3; i++)
                        AddFin(visualRoot, new Vector3(side * .19f, -.11f, .1f - i * .22f), new Vector3(.24f, .5f, .32f), fin, side * 65f);
                }
                AddEyes(new Vector3(-.18f, .22f, .64f), new Vector3(.18f, .22f, .64f), .18f, dark);
            }
            else
            {
                SeaArt.Part("Pear shaped mantle", visualRoot, SeaArt.FishBody(), main,
                    new Vector3(0, .08f, .18f), new Vector3(.9f, 1.2f, .65f));
                for (int i = 0; i < 8; i++)
                {
                    float angle = i * 45f;
                    float radians = angle * Mathf.Deg2Rad;
                    var arm = SeaArt.Part("Tentacle", visualRoot, SeaArt.Arm(i), i % 2 == 0 ? main : belly,
                        new Vector3(Mathf.Sin(radians) * .28f, -.1f, Mathf.Cos(radians) * .28f), Vector3.one).transform;
                    arm.localRotation = Quaternion.Euler(0, angle + 180f, 0);
                    for (int cup = 0; cup < 3; cup++)
                        AddSphere("Pearl sucker", arm, new Vector3(.035f, -.17f, -.20f - cup * .19f), new Vector3(.075f, .035f, .075f), belly);
                    SeaArt.CombineDetails(arm);
                }
                AddEyes(new Vector3(-.23f, .27f, .57f), new Vector3(.23f, .27f, .57f), .24f, dark);
            }
            SeaArt.CombineDetails(eyes);
            SeaArt.CombineDetails(visualRoot);
        }

        void AddEyes(Vector3 left, Vector3 right, float size, Material dark)
        {
            eyes = new GameObject("Expressive eyes").transform;
            eyes.SetParent(visualRoot, false);
            Material white = Solid(new Color(1f, .98f, .92f), .58f);
            Material iris = Solid(new Color(.08f, .25f, .31f), .65f);
            foreach (Vector3 position in new[] { left, right })
            {
                AddSphere("Eye rim", eyes, position, Vector3.one * (size * 1.12f), dark);
                AddSphere("Eye white", eyes, position + new Vector3(0, .035f, .025f), Vector3.one * size, white);
                AddSphere("Iris", eyes, position + new Vector3(0, .09f, .08f), new Vector3(size * .58f, size * .55f, size * .45f), iris);
                AddSphere("Pupil", eyes, position + new Vector3(0, .11f, .105f), Vector3.one * (size * .34f), dark);
                AddSphere("Eye sparkle", eyes, position + new Vector3(-.025f, .14f, .12f), Vector3.one * (size * .16f), white);
            }
        }

        void AnimateBody(float dt, float speedMultiplier)
        {
            swimPhase += dt * (IsPlayer ? 9f : IsPreparingChase ? 12f : 6f);
            turnBank = Mathf.Lerp(turnBank, targetBank, 1f - Mathf.Exp(-9f * dt));
            float currentScale = Mathf.Lerp(transform.localScale.x, targetScale, 1f - Mathf.Exp(-1.3f * dt));
            transform.localScale = Vector3.one * currentScale;
            biteRemaining = Mathf.Max(0, biteRemaining - dt);
            float bite = Mathf.Sin(Mathf.Clamp01(biteRemaining / .22f) * Mathf.PI);
            if (importedVisual != null)
            {
                importedVisual.UpdateSwimming(speedMultiplier > 1.1f || IsPreparingChase);
                visualRoot.localRotation = Quaternion.Euler(0, 0, turnBank);
                visualRoot.localPosition = visualRestPosition + new Vector3(0, Mathf.Sin(swimPhase * .5f) * .025f, bite * .10f);
                return;
            }
            if (tail != null) tail.localRotation = Quaternion.Euler(0, Mathf.Sin(swimPhase) * (IsPreparingChase ? 32f : 22f), 0);
            if (visualRoot == null) return;
            visualRoot.localRotation = Quaternion.Euler(0, Mathf.Sin(swimPhase) * 2.5f, turnBank + Mathf.Sin(swimPhase * .5f) * 2f);
            visualRoot.localPosition = visualRestPosition + new Vector3(0, Mathf.Sin(swimPhase * .5f) * .025f, bite * .10f);
            if (Kind == SeaCreatureKind.Octopus)
            {
                visualRoot.localScale = new Vector3(1f, 1f + Mathf.Sin(swimPhase * .7f) * .045f, 1f);
                int armIndex = 0;
                foreach (Transform arm in visualRoot)
                    if (arm.name == "Tentacle")
                    {
                        arm.localRotation = Quaternion.Euler(Mathf.Sin(swimPhase + armIndex * .7f) * 9f, armIndex * 45f + 180f, 0);
                        armIndex++;
                    }
            }
            else
            {
                int side = -1;
                foreach (Transform part in visualRoot)
                    if (part.name == "Pectoral fin")
                    {
                        part.localRotation = Quaternion.Euler(Mathf.Sin(swimPhase + 1f) * 12f, side * 70f, side * 8f);
                        side = -side;
                    }
            }
        }

        static void AddFin(Transform parent, Vector3 position, Vector3 scale, Material material, float yaw)
        {
            var fin = SeaArt.Part("Pectoral fin", parent, SeaArt.Fin(false), material, position, scale);
            fin.transform.localRotation = Quaternion.Euler(0, yaw, 0);
        }

        static Material Solid(Color color, float gloss)
        {
            return SeaArt.Solid(color, gloss);
        }

        static GameObject AddSphere(string name, Transform parent, Vector3 position, Vector3 scale, Material material)
        {
            return SeaArt.Part(name, parent, SeaArt.Pearl(), material, position, scale);
        }

    }
}
