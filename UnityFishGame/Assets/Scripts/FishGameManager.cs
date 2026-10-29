using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Chinsekid.FishGame
{
    public sealed class FishGameManager : MonoBehaviour
    {
        enum PowerUpKind { Speed, Magnet }
        const int MaximumFishCount = 48;
        const int DesiredVisibleFish = 8;
        const int DesiredEdibleFish = 5;
        int desiredVisibleThreats = 4;
        int comfortableVisibleLimit = 10;
        int maxConcurrentChasers = 2;
        int maxMines = 3;
        float mineIntervalMin = 20f;
        float mineIntervalMax = 28f;
        const int ScorePerLevel = 91;
        // Closer, lower camera reveals the fish silhouettes and side colors.
        static readonly Vector3 FollowCameraOffset = new Vector3(0, 16, 17);
        static readonly Quaternion FollowCameraRotation = Quaternion.LookRotation(-FollowCameraOffset, Vector3.up);
        static readonly Color[] Palette = {
            new Color(1f, .36f, .17f), new Color(.22f, .64f, .9f), new Color(.96f, .68f, .2f),
            new Color(.32f, .78f, .59f), new Color(.91f, .34f, .58f), new Color(.66f, .53f, .92f),
            new Color(.55f, .78f, .84f), new Color(.93f, .48f, .25f)
        };

        readonly List<FishActor> fish = new();
        readonly List<Transform> food = new();
        readonly List<MeatPickup> meat = new();
        readonly List<Transform> powerUps = new();
        readonly List<Transform> seaMines = new();
        readonly HashSet<FishActor> dispersingFish = new();
        FishGameFeedback feedback;
        Image growthFill;
        Image growthMarker;
        Texture2D hudShapeTexture;
        Sprite hudShapeSprite;
        Texture2D hudGlowTexture;
        Sprite hudGlowSprite;
        FishActor player;
        Camera gameCamera;
        Transform oceanFloor;
        EndlessSeaWorld endlessSea;
        float populationTimer;
        FishLevelOverlay fishLevels;
        Text levelText;
        Text scoreText;
        Text effectText;
        Text gainText;
        Vector3 target;
        int score;
        int eaten;
        bool boosting;
        int steeringFingerId = -1;
        bool finished;
        float waveTimer = 20f;
        float hunterCheckTimer = 1f;
        float powerUpSpawnTimer = 11f;
        float mineSpawnTimer = 18f;
        float speedPowerUpRemaining;
        float magnetPowerUpRemaining;
        float hazardSlowRemaining;
        float uiTimer;
        float cameraEmphasisRemaining;
        float nearMissCooldown;
        float shownGrowthProgress;
        float growthPulseRemaining;
        float levelFlashRemaining;
        float gainTextRemaining;
        int gainTextAmount;
        readonly HashSet<FishActor> nearMissInside = new();
        Image chaseEdgeCue;
        Texture2D chaseCueTexture;
        Sprite chaseCueSprite;
        Vector3 nearestChaserPosition;
        bool hasActiveChaser;
        bool initialized;
        string selectedFishSkin = "clownfish";

#if UNITY_IOS && !UNITY_EDITOR
        [DllImport("__Internal")] static extern void ChinsekidFishGameDidFinish(int score, int level, int eaten);
        [DllImport("__Internal")] static extern System.IntPtr ChinsekidFishGameCopySelectedSkin();
        [DllImport("__Internal")] static extern System.IntPtr ChinsekidFishGameCopyDifficulty();
        [DllImport("__Internal")] static extern void ChinsekidFishGameFreeString(System.IntPtr value);
#endif

        void Start()
        {
            Object.DontDestroyOnLoad(gameObject);
            Initialize();
        }

        public void Initialize()
        {
            if (initialized) return;
            initialized = true;
            Application.targetFrameRate = 60;
            QualitySettings.vSyncCount = 0;
            QualitySettings.antiAliasing = 2;
            ConfigureDifficulty();
            CreateOcean();
            CreateCamera();
            CreateDecor();
            CreatePlayer();
            feedback = gameObject.AddComponent<FishGameFeedback>();
            feedback.Initialize();
            CreateSchool();
            CreateUI();
            var levelOverlay = new GameObject("Fish level labels", typeof(RectTransform));
            levelOverlay.transform.SetParent(transform, false);
            fishLevels = levelOverlay.AddComponent<FishLevelOverlay>();
            fishLevels.Initialize();
            target = player.transform.position + Vector3.forward * 8;
            endlessSea.Follow(player.transform.position);
            MaintainPopulation(true);
        }

        void Update()
        {
            if (finished || player == null) return;
            float dt = Mathf.Min(Time.deltaTime, 0.04f);
            cameraEmphasisRemaining = Mathf.Max(0f, cameraEmphasisRemaining - dt);
            nearMissCooldown = Mathf.Max(0f, nearMissCooldown - dt);
            growthPulseRemaining = Mathf.Max(0f, growthPulseRemaining - dt);
            levelFlashRemaining = Mathf.Max(0f, levelFlashRemaining - dt);
            gainTextRemaining = Mathf.Max(0f, gainTextRemaining - dt);
            ReadInput();
            float speedMultiplier = speedPowerUpRemaining > 0 ? 1.55f : 1f;
            player.SwimToward(target, dt, speedMultiplier * (hazardSlowRemaining > 0 ? .68f : 1f));
            feedback.UpdateWake(player, dt, steeringFingerId >= 0 || Input.GetMouseButton(0));
            KeepInWorld(player.transform);
            RebaseWorldIfNeeded();
            UpdateCamera(dt);
            endlessSea.Follow(player.transform.position);
            populationTimer -= dt;
            if (populationTimer <= 0)
            {
                populationTimer = .4f;
                MaintainPopulation(false);
            }
            UpdateFish(dt);
            if (finished) return;
            UpdateChaseCue();
            UpdateFood(dt);
            UpdateMeat(dt);
            UpdatePowerUps(dt);
            UpdateSeaMines(dt);
            UpdateSchoolWave(dt);
            speedPowerUpRemaining = Mathf.Max(0, speedPowerUpRemaining - dt);
            magnetPowerUpRemaining = Mathf.Max(0, magnetPowerUpRemaining - dt);
            hazardSlowRemaining = Mathf.Max(0, hazardSlowRemaining - dt);
            powerUpSpawnTimer -= dt;
            if (powerUpSpawnTimer <= 0)
            {
                powerUpSpawnTimer = Random.Range(15f, 21f);
                if (powerUps.Count < 3) SpawnPowerUp();
            }
            mineSpawnTimer -= dt;
            if (player.Level >= 3 && mineSpawnTimer <= 0)
            {
                mineSpawnTimer = Random.Range(mineIntervalMin, mineIntervalMax);
                if (seaMines.Count < maxMines) SpawnSeaMine();
            }
            hunterCheckTimer -= dt;
            if (hunterCheckTimer <= 0)
            {
                hunterCheckTimer = 1f;
                EnsureHunters();
            }
            UpdateHUD(dt);
        }

        void LateUpdate()
        {
            if (fishLevels != null && gameCamera != null && player != null)
                fishLevels.Refresh(gameCamera, player, fish);
        }

        void ConfigureDifficulty()
        {
            string difficulty = "standard";
#if UNITY_IOS && !UNITY_EDITOR
            System.IntPtr nativeValue = ChinsekidFishGameCopyDifficulty();
            if (nativeValue != System.IntPtr.Zero)
            {
                difficulty = Marshal.PtrToStringUTF8(nativeValue) ?? difficulty;
                ChinsekidFishGameFreeString(nativeValue);
            }
#endif
            switch (difficulty)
            {
                case "beginner":
                    desiredVisibleThreats = 2; maxConcurrentChasers = 1; maxMines = 1;
                    mineIntervalMin = 32f; mineIntervalMax = 42f;
                    FishActor.ChaseWindupDuration = 1.2f;
                    FishActor.ChaseMinDuration = 3f; FishActor.ChaseMaxDuration = 4f;
                    FishActor.ChaseMinCooldown = 14f; FishActor.ChaseMaxCooldown = 18f;
                    break;
                case "easy":
                    desiredVisibleThreats = 3; maxConcurrentChasers = 1; maxMines = 2;
                    mineIntervalMin = 27f; mineIntervalMax = 36f;
                    FishActor.ChaseWindupDuration = .85f;
                    FishActor.ChaseMinDuration = 3.5f; FishActor.ChaseMaxDuration = 5f;
                    FishActor.ChaseMinCooldown = 11f; FishActor.ChaseMaxCooldown = 15f;
                    break;
                case "hard":
                    desiredVisibleThreats = 5; maxConcurrentChasers = 2; maxMines = 3;
                    mineIntervalMin = 19f; mineIntervalMax = 27f;
                    FishActor.ChaseWindupDuration = .42f;
                    FishActor.ChaseMinDuration = 4.5f; FishActor.ChaseMaxDuration = 6.5f;
                    FishActor.ChaseMinCooldown = 7f; FishActor.ChaseMaxCooldown = 10f;
                    break;
                case "challenge":
                    desiredVisibleThreats = 6; comfortableVisibleLimit = 11;
                    maxConcurrentChasers = 3; maxMines = 4;
                    mineIntervalMin = 16f; mineIntervalMax = 23f;
                    FishActor.ChaseWindupDuration = .32f;
                    FishActor.ChaseMinDuration = 5f; FishActor.ChaseMaxDuration = 7f;
                    FishActor.ChaseMinCooldown = 6f; FishActor.ChaseMaxCooldown = 9f;
                    break;
                default:
                    FishActor.ChaseWindupDuration = .52f;
                    FishActor.ChaseMinDuration = 4f; FishActor.ChaseMaxDuration = 6f;
                    FishActor.ChaseMinCooldown = 8f; FishActor.ChaseMaxCooldown = 12f;
                    break;
            }
            mineSpawnTimer = mineIntervalMin - 2f;
        }

        void CreateOcean()
        {
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(.60f, .76f, .86f);
            RenderSettings.ambientEquatorColor = new Color(.31f, .49f, .64f);
            RenderSettings.ambientGroundColor = new Color(.20f, .31f, .46f);
            RenderSettings.fog = true;
            RenderSettings.fogColor = new Color(.045f, .20f, .35f);
            RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.fogDensity = .012f;
            var lightObject = new GameObject("Sunlight through the water");
            var light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = new Color(1f, .95f, .84f);
            light.intensity = 1.1f;
            lightObject.transform.rotation = Quaternion.Euler(48, -30, 0);

            var floor = GameObject.CreatePrimitive(PrimitiveType.Plane);
            floor.name = "Deep blue reef floor";
            floor.transform.position = new Vector3(0, -1.25f, 0);
            floor.transform.localScale = new Vector3(16, 1, 13);
            var seabed = new Material(Resources.Load<Material>("OpenSea/Environment/Seabed") ?? SeaArt.Sand());
            var lagoonShader = Resources.Load<Shader>("LagoonSand");
            if (lagoonShader != null) seabed.shader = lagoonShader;
            floor.GetComponent<Renderer>().sharedMaterial = seabed;
            floor.GetComponent<Collider>().enabled = false;
            oceanFloor = floor.transform;
            ColorfulReefArt.Water(transform);
        }

        void CreateCamera()
        {
            var cameraObject = new GameObject("Follow camera");
            gameCamera = cameraObject.AddComponent<Camera>();
            if (FindAnyObjectByType<AudioListener>() == null) cameraObject.AddComponent<AudioListener>();
            gameCamera.clearFlags = CameraClearFlags.SolidColor;
            gameCamera.backgroundColor = RenderSettings.fogColor;
            gameCamera.orthographic = true;
            gameCamera.orthographicSize = 4.5f / Mathf.Min(1f, gameCamera.aspect);
            cameraObject.transform.position = FollowCameraOffset;
            cameraObject.transform.rotation = FollowCameraRotation;
            gameCamera.nearClipPlane = .1f;
            gameCamera.farClipPlane = 260f;
            gameCamera.allowHDR = true;
            gameCamera.allowMSAA = true;
        }

        void CreatePlayer()
        {
            var body = new GameObject("Player fish");
            body.transform.position = new Vector3(0, .3f, 0);
            player = body.AddComponent<FishActor>();
            var skin = ReadPlayerSkin();
            player.Configure(1, skin.kind, skin.color, true, OpenSeaFishVisual.ModelForSkin(selectedFishSkin));
            target = body.transform.position + Vector3.forward * 8;
        }

        (SeaCreatureKind kind, Color color) ReadPlayerSkin()
        {
            string skinName = "clownfish";
#if UNITY_IOS && !UNITY_EDITOR
            System.IntPtr nativeValue = ChinsekidFishGameCopySelectedSkin();
            if (nativeValue != System.IntPtr.Zero)
            {
                skinName = Marshal.PtrToStringUTF8(nativeValue) ?? skinName;
                ChinsekidFishGameFreeString(nativeValue);
            }
#endif
            selectedFishSkin = skinName;
            return skinName switch
            {
                "puffer" or "butterfly" => (SeaCreatureKind.Fish, new Color(.97f, .70f, .25f)),
                "tang" or "blueMinnow" => (SeaCreatureKind.Fish, new Color(.24f, .58f, .85f)),
                "green" => (SeaCreatureKind.Fish, new Color(.20f, .68f, .49f)),
                "shark" or "reefShark" => (SeaCreatureKind.Fish, new Color(.42f, .57f, .63f)),
                "angler" or "octopus" => (skinName == "octopus" ? SeaCreatureKind.Octopus : SeaCreatureKind.Fish, new Color(.62f, .38f, .68f)),
                "stripedCoral" => (SeaCreatureKind.Fish, new Color(.91f, .28f, .57f)),
                "redfin" => (SeaCreatureKind.Fish, new Color(.91f, .57f, .23f)),
                "tealPuffer" => (SeaCreatureKind.Fish, new Color(.17f, .65f, .63f)),
                "silverfish" or "longfinFish" => (SeaCreatureKind.Fish, new Color(.62f, .70f, .76f)),
                "shrimp" => (SeaCreatureKind.Shrimp, new Color(.98f, .48f, .58f)),
                _ => (SeaCreatureKind.Fish, Palette[0])
            };
        }

        void CreateSchool()
        {
            // A generous food field means the visible area never feels empty.
            for (int i = 0; i < 74; i++) SpawnFood(RandomPoint(), Random.value < .13f ? 2 : 1);
            string[] referenceFish = { "PatternedReef", "RubyLionfish", "SpottedPuffer", "AzureAngelfish", "FangHunter", "GrinningShark" };
            for (int i = 0; i < 16; i++)
            {
                string model = i < 3 ? "GoldenReference" : i < 9 ? referenceFish[i - 3] : null;
                int level = i == 7 ? 3 : i == 8 ? 4 : Random.Range(1, 3);
                SpawnFish(level, SeaCreatureKind.Fish, false, model);
            }
            for (int i = 0; i < 8; i++) SpawnFish(Random.Range(1, 4), i % 3 == 0 ? SeaCreatureKind.Shrimp : SeaCreatureKind.Fish, false);
            for (int i = 0; i < 4; i++) SpawnFish(Random.Range(2, 5), i % 2 == 0 ? SeaCreatureKind.Octopus : SeaCreatureKind.Fish, false);
            SpawnFish(6, SeaCreatureKind.Fish, true, "IridescentShark");
            EnsureHunters();
        }

        void SpawnFish(int level, SeaCreatureKind kind, bool hunter, string selectedModel = null)
        {
            var fishObject = new GameObject(hunter ? "Predator" : "School fish");
            fishObject.transform.position = RandomPoint();
            if (player != null && Vector3.Distance(fishObject.transform.position, player.transform.position) < 9f)
                fishObject.transform.position = SpawnAtSafeDistance(12f, 34f);
            var actor = fishObject.AddComponent<FishActor>();
            actor.Configure(level, kind, Palette[Random.Range(0, Palette.Length)], selectedModel: selectedModel);
            actor.IsHunter = hunter;
            fish.Add(actor);
        }

        void EnsureHunters()
        {
            int level = player == null ? 1 : player.Level;
            int desired = 2 + Mathf.Min(1, level / 10);
            foreach (var hunter in fish)
                if (hunter != null && hunter.IsHunter && hunter.Level <= level)
                    hunter.SetLevel(level + Random.Range(1, 3));
            int current = fish.FindAll(item => item != null && item.IsHunter).Count;
            while (current++ < desired && fish.Count < MaximumFishCount)
            {
                var actor = new GameObject("Roaming hunter").AddComponent<FishActor>();
                actor.transform.position = SpawnAtSafeDistance(30f, 46f);
                actor.Configure(level + 2 + Random.Range(0, 2), Random.value < .28f ? SeaCreatureKind.Octopus : SeaCreatureKind.Fish, Palette[Random.Range(0, Palette.Length)]);
                actor.IsHunter = true;
                fish.Add(actor);
            }
        }

        void SpawnFood(Vector3 position, int value)
        {
            var orb = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            orb.name = value == 2 ? "Large glowing food" : "Glowing food";
            orb.transform.position = new Vector3(position.x, .1f, position.z);
            float size = value == 2 ? .34f : .2f;
            orb.transform.localScale = Vector3.one * size;
            orb.GetComponent<Collider>().enabled = false;
            var mat = MakeMaterial(value == 2 ? new Color(1f, .74f, .25f) : new Color(.39f, .93f, .92f), .75f);
            if (mat.HasProperty("_EmissionColor"))
            {
                mat.EnableKeyword("_EMISSION");
                mat.SetColor("_EmissionColor", mat.color * 1.35f);
            }
            orb.GetComponent<Renderer>().material = mat;
            orb.gameObject.AddComponent<FoodValue>().Value = value;
            food.Add(orb.transform);
        }

        void SpawnMeat(Vector3 position)
        {
            if (meat.Count >= 12)
            {
                if (meat[0] != null) Destroy(meat[0].gameObject);
                meat.RemoveAt(0);
            }
            Vector2 direction = Random.insideUnitCircle.normalized;
            if (direction.sqrMagnitude < .01f) direction = Vector2.right;
            float distance = player.Size + Random.Range(1.3f, 2f);
            Vector3 landing = position + new Vector3(direction.x, 0f, direction.y) * distance;
            var pickup = new GameObject("Dropped steak").AddComponent<MeatPickup>();
            pickup.Initialize(position, landing);
            meat.Add(pickup);
            feedback.DropMeat(position);
        }

        void SpawnPowerUp()
        {
            PowerUpKind kind = (PowerUpKind)Random.Range(0, 2);
            Color color = kind switch
            {
                PowerUpKind.Speed => new Color(.38f, .78f, 1f),
                _ => new Color(.86f, .53f, 1f)
            };
            var orb = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            orb.name = "Power-up: " + kind;
            orb.transform.position = RandomPoint(18f) + Vector3.up * .4f;
            orb.transform.localScale = Vector3.one * .62f;
            orb.GetComponent<Collider>().enabled = false;
            orb.GetComponent<Renderer>().material = MakeMaterial(color, 1f);
            orb.AddComponent<PowerUpToken>().Kind = kind;
            powerUps.Add(orb.transform);
        }

        void SpawnSeaMine()
        {
            var mine = new GameObject("Spiny sea urchin");
            mine.transform.position = SpawnAtSafeDistance(20f, 42f);
            var center = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            center.name = "Urchin body";
            center.transform.SetParent(mine.transform, false);
            center.transform.localScale = Vector3.one * .7f;
            center.GetComponent<Collider>().enabled = false;
            center.GetComponent<Renderer>().material = MakeMaterial(new Color(.92f, .35f, .34f), .18f);
            for (int i = 0; i < 9; i++)
            {
                float angle = i * Mathf.PI * 2f / 9f;
                var spine = GameObject.CreatePrimitive(PrimitiveType.Capsule);
                spine.name = "Urchin spine";
                spine.transform.SetParent(mine.transform, false);
                spine.transform.localPosition = new Vector3(Mathf.Cos(angle) * .42f, .05f, Mathf.Sin(angle) * .42f);
                spine.transform.localRotation = Quaternion.Euler(0, 0, Mathf.Sin(angle) * 55f);
                spine.transform.localScale = new Vector3(.11f, .48f, .11f);
                spine.GetComponent<Collider>().enabled = false;
                spine.GetComponent<Renderer>().material = MakeMaterial(new Color(1f, .69f, .37f), .1f);
            }
            seaMines.Add(mine.transform);
        }

        void CreateDecor()
        {
            ColorfulReefArt.Populate(transform);
            var bubbles = new GameObject("Rising bubbles");
            var particle = bubbles.AddComponent<ParticleSystem>();
            // A dynamically added ParticleSystem has no packaged default material.
            var bubbleTexture = new Texture2D(32, 32, TextureFormat.RGBA32, false);
            bubbleTexture.wrapMode = TextureWrapMode.Clamp;
            for (int y = 0; y < 32; y++)
                for (int x = 0; x < 32; x++)
                {
                    float radius = new Vector2((x - 15.5f) / 15.5f, (y - 15.5f) / 15.5f).magnitude;
                    float rim = Mathf.Exp(-Mathf.Pow((radius - .75f) / .10f, 2f));
                    float alpha = rim * .65f + (1f - Mathf.SmoothStep(0, 1, radius)) * .10f;
                    bubbleTexture.SetPixel(x, y, new Color(1, 1, 1, alpha));
                }
            bubbleTexture.Apply();
            particle.GetComponent<ParticleSystemRenderer>().material = new Material(Shader.Find("Sprites/Default"))
            {
                mainTexture = bubbleTexture
            };
            var main = particle.main;
            main.loop = true;
            main.startLifetime = 8f;
            main.startSpeed = .55f;
            main.startSize = new ParticleSystem.MinMaxCurve(.035f, .13f);
            main.startColor = new Color(.75f, .95f, 1f, .38f);
            var emission = particle.emission;
            emission.rateOverTime = 26f;
            var shape = particle.shape;
            shape.shapeType = ParticleSystemShapeType.Box;
            shape.scale = new Vector3(36, .2f, 28);
            particle.transform.position = new Vector3(0, .2f, 0);
            endlessSea = gameObject.AddComponent<EndlessSeaWorld>();
            endlessSea.Initialize(transform, oceanFloor, particle.transform);
        }

        void CreateUI()
        {
            CreateHudSprites();
            var canvasObject = new GameObject("Game HUD", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            var canvas = canvasObject.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvasObject.GetComponent<CanvasScaler>().uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            canvasObject.GetComponent<CanvasScaler>().referenceResolution = new Vector2(1280, 800);
            CreateChaseCue(canvas.transform);
            var top = AddPanel(canvas.transform, "Growth badge", new Vector2(.5f, 1), new Vector2(370, 112), new Vector2(0, -72), Color.clear);
            top.GetComponent<Image>().raycastTarget = false;
            levelText = AddText(top.transform, "Lv. 1", 34, FontStyle.Bold, new Vector2(0, 30), new Vector2(220, 40), Color.white);
            foreach (float side in new[] { -1f, 1f })
            {
                var line = AddPanel(top.transform, "Level accent", new Vector2(.5f, .5f),
                    new Vector2(32, 2), new Vector2(side * 133f, 30), new Color(.64f, .94f, 1f, .62f));
                line.GetComponent<Image>().raycastTarget = false;
            }
            scoreText = AddText(top.transform, "成长 0 / 91  ·  吃鱼 0", 20, FontStyle.Normal, new Vector2(0, 1), new Vector2(340, 28), new Color(.84f, .96f, 1f));
            var track = AddPanel(top.transform, "Growth progress track", new Vector2(.5f, .5f), new Vector2(300, 10), new Vector2(0, -24), new Color(.025f, .15f, .22f, .58f));
            track.GetComponent<Image>().raycastTarget = false;
            track.GetComponent<Image>().sprite = hudShapeSprite;
            track.GetComponent<Image>().type = Image.Type.Sliced;
            var fill = AddPanel(track.transform, "Growth progress fill", Vector2.zero, Vector2.zero, Vector2.zero, new Color(.70f, .94f, .85f));
            growthFill = fill.GetComponent<Image>(); growthFill.raycastTarget = false;
            growthFill.sprite = hudShapeSprite;
            growthFill.type = Image.Type.Sliced;
            var fillRect = growthFill.rectTransform;
            fillRect.anchorMin = Vector2.zero; fillRect.anchorMax = new Vector2(0, 1);
            fillRect.offsetMin = fillRect.offsetMax = Vector2.zero;
            var marker = AddPanel(track.transform, "Growth light", new Vector2(.5f, .5f), new Vector2(30, 30), new Vector2(-150, 0), Color.white);
            growthMarker = marker.GetComponent<Image>();
            growthMarker.sprite = hudGlowSprite;
            growthMarker.raycastTarget = false;
            growthMarker.enabled = false;
            effectText = AddText(top.transform, "", 18, FontStyle.Bold, new Vector2(0, -47), new Vector2(340, 26), new Color(.63f, .94f, 1f));
            gainText = AddText(top.transform, "", 20, FontStyle.Bold, new Vector2(218, -22), new Vector2(110, 28), new Color(1f, .86f, .53f, 0f));
            var exit = AddPanel(canvas.transform, "Return to app", new Vector2(1, 1), new Vector2(132, 62), new Vector2(-88, -58), Color.clear);
            AddText(exit.transform, "← 返回", 21, FontStyle.Bold, Vector2.zero, new Vector2(132, 56), new Color(.88f, .97f, 1f));
            exit.AddComponent<Button>().onClick.AddListener(ReturnToApp);
            if (EventSystem.current == null) new GameObject("EventSystem", typeof(EventSystem), typeof(StandaloneInputModule));
        }

        void CreateHudSprites()
        {
            hudShapeTexture = new Texture2D(64, 16, TextureFormat.RGBA32, false) { name = "Rounded growth track" };
            for (int y = 0; y < 16; y++)
                for (int x = 0; x < 64; x++)
                {
                    float centerX = Mathf.Clamp(x + .5f, 8f, 56f);
                    float distance = new Vector2(x + .5f - centerX, y + .5f - 8f).magnitude;
                    hudShapeTexture.SetPixel(x, y, new Color(1f, 1f, 1f, Mathf.Clamp01(8.5f - distance)));
                }
            hudShapeTexture.Apply();
            hudShapeSprite = Sprite.Create(hudShapeTexture, new Rect(0, 0, 64, 16), new Vector2(.5f, .5f), 100f,
                0, SpriteMeshType.FullRect, new Vector4(8, 8, 8, 8));

            hudGlowTexture = new Texture2D(32, 32, TextureFormat.RGBA32, false) { name = "Growth light" };
            for (int y = 0; y < 32; y++)
                for (int x = 0; x < 32; x++)
                {
                    float radius = new Vector2((x - 15.5f) / 15.5f, (y - 15.5f) / 15.5f).magnitude;
                    hudGlowTexture.SetPixel(x, y, new Color(1f, 1f, 1f, Mathf.Pow(Mathf.Clamp01(1f - radius), 2f)));
                }
            hudGlowTexture.Apply();
            hudGlowSprite = Sprite.Create(hudGlowTexture, new Rect(0, 0, 32, 32), new Vector2(.5f, .5f));
        }

        void CreateChaseCue(Transform canvas)
        {
            const int size = 64;
            chaseCueTexture = new Texture2D(size, size, TextureFormat.RGBA32, false) { name = "Chase edge water rings" };
            var pixels = new Color[size * size];
            for (int y = 0; y < size; y++)
                for (int x = 0; x < size; x++)
                {
                    float radius = new Vector2((x - 31.5f) / 31.5f, (y - 31.5f) / 31.5f).magnitude;
                    float outer = Mathf.Exp(-Mathf.Pow((radius - .78f) / .055f, 2f));
                    float inner = Mathf.Exp(-Mathf.Pow((radius - .55f) / .045f, 2f));
                    pixels[y * size + x] = new Color(1f, 1f, 1f, Mathf.Clamp01(outer * .65f + inner * .32f));
                }
            chaseCueTexture.SetPixels(pixels);
            chaseCueTexture.Apply();
            chaseCueSprite = Sprite.Create(chaseCueTexture, new Rect(0, 0, size, size), new Vector2(.5f, .5f));
            var cue = new GameObject("Active chase direction", typeof(RectTransform), typeof(Image));
            cue.transform.SetParent(canvas, false);
            chaseEdgeCue = cue.GetComponent<Image>();
            chaseEdgeCue.sprite = chaseCueSprite;
            chaseEdgeCue.raycastTarget = false;
            chaseEdgeCue.rectTransform.sizeDelta = new Vector2(110, 110);
            cue.transform.SetAsFirstSibling();
            cue.SetActive(false);
        }

        void UpdateChaseCue()
        {
            if (chaseEdgeCue == null) return;
            chaseEdgeCue.gameObject.SetActive(hasActiveChaser);
            if (!hasActiveChaser) return;
            Vector3 viewport = gameCamera.WorldToViewportPoint(nearestChaserPosition);
            Vector2 direction = new Vector2((viewport.x - .5f) * gameCamera.aspect, viewport.y - .5f);
            if (direction.sqrMagnitude < .001f) direction = Vector2.up;
            direction.Normalize();
            float edge = Mathf.Min(.43f / Mathf.Max(.001f, Mathf.Abs(direction.x)),
                .39f / Mathf.Max(.001f, Mathf.Abs(direction.y)));
            Vector2 anchor = new Vector2(.5f, .5f) + direction * edge;
            chaseEdgeCue.rectTransform.anchorMin = anchor;
            chaseEdgeCue.rectTransform.anchorMax = anchor;
            chaseEdgeCue.rectTransform.anchoredPosition = Vector2.zero;
            float pulse = .5f + .5f * Mathf.Sin(Time.time * 7f);
            chaseEdgeCue.rectTransform.sizeDelta = Vector2.one * Mathf.Lerp(105f, 125f, pulse);
            chaseEdgeCue.color = new Color(.68f, .94f, 1f, Mathf.Lerp(.18f, .28f, pulse));
        }

        public void SetBoosting(bool value) => boosting = value;

        void ReadInput()
        {
            if (Input.touchCount > 0)
            {
                // Keep steering attached to the water finger, regardless of which
                // finger Unity lists first when the boost button is held.
                for (int i = 0; i < Input.touchCount; i++)
                {
                    Touch touch = Input.GetTouch(i);
                    if (touch.fingerId != steeringFingerId) continue;
                    if (touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled)
                        steeringFingerId = -1;
                    else
                    {
                        SetTarget(touch.position, touch.fingerId);
                        return;
                    }
                }
                for (int i = 0; i < Input.touchCount; i++)
                {
                    Touch touch = Input.GetTouch(i);
                    if (touch.phase != TouchPhase.Began || IsOverUI(touch.fingerId)) continue;
                    steeringFingerId = touch.fingerId;
                    SetTarget(touch.position, touch.fingerId, true);
                    break;
                }
                return;
            }
            steeringFingerId = -1;
            if (Input.GetMouseButton(0)) SetTarget(Input.mousePosition, -1, Input.GetMouseButtonDown(0));
        }

        static bool IsOverUI(int pointerId) =>
            EventSystem.current != null && EventSystem.current.IsPointerOverGameObject(pointerId);

        void SetTarget(Vector2 screenPoint, int pointerId = -1, bool showTouch = false)
        {
            if (IsOverUI(pointerId)) return;
            Ray ray = gameCamera.ScreenPointToRay(screenPoint);
            // Project the finger onto the fish's swimming height; projecting onto
            // the seabed offsets the target under a tilted perspective camera.
            Plane ocean = new Plane(Vector3.up, new Vector3(0, player.transform.position.y, 0));
            if (ocean.Raycast(ray, out float distance))
            {
                target = ray.GetPoint(distance);
                if (showTouch) feedback.TouchWater(target);
            }
        }

        // Keep the initial camera distance through early growth. Later zoom only
        // limits screen coverage after the body has visibly grown to its comfortable screen size.
        public static float CameraDistanceScale(float bodyScale) => Mathf.Max(.46f, bodyScale * .92f / 1.2f);

        void UpdateCamera(float dt)
        {
            Vector3 desired = player.transform.position + FollowCameraOffset;
            float viewSize = 4.5f * CameraDistanceScale(player.Size) / .46f / Mathf.Min(1f, gameCamera.aspect);
            float emphasis = Mathf.Sin(cameraEmphasisRemaining / .55f * Mathf.PI);
            viewSize *= 1f - .035f * Mathf.Max(0f, emphasis);
            gameCamera.orthographicSize = Mathf.Lerp(gameCamera.orthographicSize, viewSize, 1f - Mathf.Exp(-2.8f * dt));
            gameCamera.transform.position = Vector3.Lerp(gameCamera.transform.position, desired, 1f - Mathf.Exp(-2.8f * dt));
            gameCamera.transform.rotation = Quaternion.Slerp(gameCamera.transform.rotation, FollowCameraRotation, 1f - Mathf.Exp(-3f * dt));
        }

        bool IsVisible(Vector3 position)
        {
            Vector3 screen = gameCamera.WorldToViewportPoint(position);
            return screen.z > 0 && screen.x > .02f && screen.x < .98f && screen.y > .06f && screen.y < .92f;
        }

        bool TryPopulationPoint(bool edible, bool initial, out Vector3 point)
        {
            var water = new Plane(Vector3.up, new Vector3(0, .2f, 0));
            for (int attempt = 0; attempt < 40; attempt++)
            {
                float x = Random.Range(.06f, .94f), y = Random.Range(.12f, .86f);
                if (!initial)
                {
                    if (Random.value < .5f) x = Random.value < .5f ? .06f : .94f;
                    else y = Random.value < .5f ? .12f : .86f;
                }
                if (!water.Raycast(gameCamera.ViewportPointToRay(new Vector3(x, y, 0)), out float length)) continue;
                point = gameCamera.ViewportPointToRay(new Vector3(x, y, 0)).GetPoint(length);
                float distance = Vector3.Distance(point, player.transform.position);
                if (distance < (edible ? Mathf.Max(2.5f, player.Size * 3.8f) : Mathf.Max(4.5f, player.Size * 6f)) || distance > 60f) continue;
                bool crowded = false;
                foreach (var actor in fish)
                    if (actor != null && (actor.transform.position - point).sqrMagnitude < 4.8f) { crowded = true; break; }
                if (!crowded) return true;
            }
            point = Vector3.zero;
            return false;
        }

        // Keep several dangerous fish near the outer edge while leaving enough
        // edible fish for the player to grow.
        void EnsureVisibleThreat(ref int visible, ref int edible)
        {
            int threats = 0;
            foreach (var actor in fish)
                if (actor != null && actor.Level > player.Level && IsVisible(actor.transform.position)) threats++;

            while (threats < desiredVisibleThreats)
            {
                FishActor candidate = null;
                if (visible < comfortableVisibleLimit && TryPopulationPoint(false, false, out var point))
                {
                    foreach (var actor in fish)
                        if (actor != null && actor.IsHunter && !IsVisible(actor.transform.position))
                        { candidate = actor; break; }
                    if (candidate == null)
                        foreach (var actor in fish)
                            if (actor != null && !IsVisible(actor.transform.position))
                            { candidate = actor; break; }
                    if (candidate == null && fish.Count < MaximumFishCount)
                    {
                        candidate = new GameObject("Visible roaming hunter").AddComponent<FishActor>();
                        candidate.transform.position = point;
                        candidate.Configure(player.Level + 1, SeaCreatureKind.Fish, Palette[Random.Range(0, Palette.Length)]);
                        fish.Add(candidate);
                    }
                    if (candidate != null)
                    {
                        candidate.SetLevel(player.Level + Random.Range(1, 3));
                        candidate.IsHunter = true;
                        dispersingFish.Remove(candidate);
                        candidate.Relocate(point, true);
                        visible++;
                        threats++;
                        continue;
                    }
                }
                // Reuse a distant edible fish if the view is full. Keep at
                // least five edible fish available for the player.
                if (edible <= DesiredEdibleFish) break;
                float farthest = 3.5f;
                foreach (var actor in fish)
                {
                    if (actor == null || actor.IsHunter || actor.Level > player.Level || !IsVisible(actor.transform.position)) continue;
                    float distance = Vector3.Distance(actor.transform.position, player.transform.position);
                    if (distance > farthest) { farthest = distance; candidate = actor; }
                }
                if (candidate == null) break;
                candidate.SetLevel(player.Level + Random.Range(1, 3));
                candidate.IsHunter = true;
                dispersingFish.Remove(candidate);
                candidate.Relocate(candidate.transform.position, true);
                edible--;
                threats++;
            }
        }

        void MaintainPopulation(bool initial)
        {
            fish.RemoveAll(actor => actor == null);
            nearMissInside.RemoveWhere(actor => actor == null);
            int visible = 0, edible = 0, relocated = 0;
            foreach (var actor in fish)
            {
                if (!IsVisible(actor.transform.position)) continue;
                visible++;
                if (actor.Level <= player.Level) edible++;
            }
            foreach (var actor in fish)
            {
                float distance = Vector3.Distance(actor.transform.position, player.transform.position);
                if (distance <= 60f || IsVisible(actor.transform.position) || relocated >= 6) continue;
                Vector3 point;
                // Predators return farther away, never directly on the player.
                // Excess fish wait outside the view instead of piling onto its edges.
                if (actor.IsHunter || actor.Level > player.Level || visible >= comfortableVisibleLimit)
                    point = SpawnAtSafeDistance(28f, 44f);
                else if (!TryPopulationPoint(true, false, out point)) continue;
                actor.Relocate(point);
                relocated++;
                if (IsVisible(actor.transform.position))
                {
                    visible++;
                    if (actor.Level <= player.Level) edible++;
                }
            }
            EnsureVisibleThreat(ref visible, ref edible);
            int budget = initial ? 8 : 2;
            while (visible < comfortableVisibleLimit && (visible < DesiredVisibleFish || edible < DesiredEdibleFish) && budget-- > 0)
            {
                if (!TryPopulationPoint(true, initial, out var point)) break;
                FishActor candidate = null;
                float farthest = 32f;
                foreach (var actor in fish)
                {
                    float distance = Vector3.Distance(actor.transform.position, player.transform.position);
                    if (!actor.IsHunter && !IsVisible(actor.transform.position) && distance > farthest)
                    { candidate = actor; farthest = distance; }
                }
                int level = Mathf.Max(1, player.Level - Random.Range(0, 3));
                if (candidate != null)
                {
                    candidate.SetLevel(level);
                    candidate.Relocate(point);
                }
                else
                {
                    if (fish.Count >= MaximumFishCount) break;
                    candidate = new GameObject("Nearby roaming fish").AddComponent<FishActor>();
                    candidate.transform.position = point;
                    candidate.Configure(level, SeaCreatureKind.Fish, Palette[Random.Range(0, Palette.Length)]);
                    fish.Add(candidate);
                }
                visible++;
                edible++;
            }
            // Ease excess fish out through the edges; never despawn visible fish.
            dispersingFish.RemoveWhere(actor => actor == null || !IsVisible(actor.transform.position));
            int surplus = visible - comfortableVisibleLimit - dispersingFish.Count;
            for (int i = fish.Count - 1; i >= 0 && surplus > 0; i--)
            {
                var actor = fish[i];
                if (actor.IsHunter || dispersingFish.Contains(actor) || !IsVisible(actor.transform.position) ||
                    Vector3.Distance(actor.transform.position, player.transform.position) < 3f) continue;
                dispersingFish.Add(actor); surplus--;
            }
            foreach (var orb in food)
                if (orb != null && Vector3.Distance(orb.position, player.transform.position) > 60f)
                    orb.position = RandomPoint(34f);
            for (int i = 0; i < 4 && food.Count < 74; i++) SpawnFood(RandomPoint(34f), Random.value < .12f ? 2 : 1);
            foreach (var item in powerUps)
                if (item != null && Vector3.Distance(item.position, player.transform.position) > 60f)
                    item.position = SpawnAtSafeDistance(12f, 28f);
            foreach (var mine in seaMines)
                if (mine != null && Vector3.Distance(mine.position, player.transform.position) > 60f)
                    mine.position = SpawnAtSafeDistance(24f, 42f);
        }

        void RebaseWorldIfNeeded()
        {
            Vector3 position = player.transform.position;
            if (Mathf.Abs(position.x) < 2000f && Mathf.Abs(position.z) < 2000f) return;
            var offset = new Vector3(Mathf.Round(position.x / 80f) * 80f, 0, Mathf.Round(position.z / 80f) * 80f);
            player.ShiftOrigin(offset);
            foreach (var actor in fish) if (actor != null) actor.ShiftOrigin(offset);
            foreach (var orb in food) if (orb != null) orb.position -= offset;
            foreach (var pickup in meat) if (pickup != null) pickup.ShiftOrigin(offset);
            foreach (var item in powerUps) if (item != null) item.position -= offset;
            foreach (var mine in seaMines) if (mine != null) mine.position -= offset;
            target -= offset;
            gameCamera.transform.position -= offset;
            endlessSea.ShiftOrigin(offset);
            feedback.ShiftOrigin(offset);
        }

        void UpdateFish(float dt)
        {
            int activeChasers = 0;
            float nearestChaserGap = float.MaxValue;
            hasActiveChaser = false;
            for (int i = fish.Count - 1; i >= 0; i--)
            {
                FishActor actor = fish[i];
                if (actor == null) { fish.RemoveAt(i); continue; }
                float gap = Vector3.Distance(actor.transform.position, player.transform.position);
                Vector3 separation = CalculateSeparation(actor, i);
                bool chasing = actor.UpdateChase(player.transform.position,
                    activeChasers < maxConcurrentChasers && !dispersingFish.Contains(actor) && actor.Level > player.Level &&
                    gap < (actor.IsHunter ? 12f : 6.5f), dt);
                if (chasing || actor.IsPreparingChase) activeChasers++;
                if (actor.ChaseWarningStarted) feedback.ChaseWarning(actor.transform.position, actor.Size);
                if (chasing && gap < nearestChaserGap)
                {
                    nearestChaserGap = gap;
                    nearestChaserPosition = actor.transform.position;
                    hasActiveChaser = true;
                }
                if (dispersingFish.Contains(actor))
                {
                    Vector3 away = actor.transform.position - player.transform.position; away.y = 0;
                    if (away.sqrMagnitude < .01f) away = actor.transform.forward;
                    Vector3 destination = actor.transform.position + away.normalized * 18f;
                    actor.SetTarget(destination);
                    actor.SwimToward(destination, dt);
                }
                else if (chasing)
                    actor.SwimToward(player.transform.position + separation * 1.6f, dt, gap < 10f ? 1.08f : 1f);
                else if (separation.sqrMagnitude > .04f)
                    actor.SwimToward(actor.transform.position + separation * 5f, dt);
                else actor.Wander(dt);
                KeepInWorld(actor.transform);
                FeedCompetitorFish(actor);

                gap = Vector3.Distance(actor.transform.position, player.transform.position);
                float collisionDistance = (actor.Size + player.Size) * .75f;
                float nearDistance = collisionDistance + Mathf.Max(.42f, player.Size * .9f);
                if (actor.Level > player.Level && gap > collisionDistance && gap < nearDistance)
                {
                    if (nearMissInside.Add(actor) && nearMissCooldown <= 0f &&
                        (player.Velocity.sqrMagnitude > .25f || actor.Velocity.sqrMagnitude > .25f))
                    {
                        feedback.NearMiss(player.transform.position, player.Size);
                        nearMissCooldown = 1.2f;
                    }
                }
                else if (gap > nearDistance * 1.5f || actor.Level <= player.Level)
                    nearMissInside.Remove(actor);

                if (gap < collisionDistance)
                {
                    if (CanEat(player.Level, actor.Level)) EatFish(actor, i);
                    else FinishGame();
                    if (finished) return;
                }
            }
        }

        void FeedCompetitorFish(FishActor actor)
        {
            for (int i = food.Count - 1; i >= 0; i--)
            {
                Transform orb = food[i];
                if (orb == null) { food.RemoveAt(i); continue; }
                if (Vector3.Distance(actor.transform.position, orb.position) >= actor.Size * .6f + .3f) continue;
                int growth = orb.GetComponent<FoodValue>().Value == 2 ? 10 : 4;
                actor.GainGrowthPoints(growth);
                food.RemoveAt(i);
                Destroy(orb.gameObject);
                break;
            }
        }

        Vector3 CalculateSeparation(FishActor actor, int ownIndex)
        {
            Vector3 steer = Vector3.zero;
            int neighbors = 0;
            for (int i = 0; i < fish.Count; i++)
            {
                if (i == ownIndex || fish[i] == null) continue;
                Vector3 offset = actor.transform.position - fish[i].transform.position;
                offset.y = 0;
                float distance = offset.magnitude;
                float desiredGap = (actor.Size + fish[i].Size) * 1.75f;
                if (distance > .01f && distance < desiredGap)
                {
                    steer += offset.normalized * (desiredGap - distance) / desiredGap;
                    neighbors++;
                }
            }
            return neighbors == 0 ? Vector3.zero : steer / neighbors;
        }

        // Rewards depend on the challenge relative to the player, never absolute
        // level. High-level prey can no longer grant several levels in one bite.
        public static int FishReward(int preyLevel, int playerLevel) => Mathf.Clamp(14 - Mathf.Max(0, playerLevel - preyLevel) * 3, 5, 14);

        public static bool CanEat(int playerLevel, int fishLevel) => fishLevel <= playerLevel;

        void EatFish(FishActor actor, int index)
        {
            // Keep the score and removal path safe even if a future caller skips
            // the collision branch's level check.
            if (actor == null || !CanEat(player.Level, actor.Level)) return;
            fish.RemoveAt(index);
            nearMissInside.Remove(actor);
            if (fishLevels != null) fishLevels.RemoveActor(actor);
            int gained = FishReward(actor.Level, player.Level);
            score += gained;
            ShowGrowthGain(gained);
            eaten++;
            feedback.Eat(actor.transform.position, player.Size);
            player.PlayBite();
            if (Random.value < .4f) SpawnMeat(actor.transform.position);
            StartCoroutine(ConsumeFish(actor, player));
            int newLevel = score / ScorePerLevel + 1;
            if (newLevel > player.Level)
            {
                player.SetLevel(newLevel);
                feedback.LevelUp(player.transform.position, player.Size);
                cameraEmphasisRemaining = .55f;
                levelFlashRemaining = .72f;
                shownGrowthProgress = 0f;
                ShowTip("升级啦！继续寻找更大的鱼！");
                EnsureHunters();
            }
            player.SetGrowthProgress((score % ScorePerLevel) / (float)ScorePerLevel);
            if (eaten % 3 == 0) SpawnPowerUp();
        }

        System.Collections.IEnumerator ConsumeFish(FishActor prey, FishActor eater)
        {
            if (prey == null || eater == null) yield break;
            Transform body = prey.transform;
            Vector3 from = body.position;
            Vector3 originalScale = body.localScale;
            Quaternion originalRotation = body.rotation;
            float elapsed = 0f;
            const float duration = .2f;
            while (elapsed < duration && body != null && eater != null)
            {
                elapsed += Time.deltaTime;
                float t = Mathf.Clamp01(elapsed / duration);
                float eased = t * t * (3f - 2f * t);
                Vector3 mouth = eater.transform.position + eater.transform.forward * (eater.Size * .8f);
                body.position = Vector3.Lerp(from, mouth, eased);
                body.localScale = originalScale * Mathf.Max(.02f, 1f - eased);
                body.rotation = originalRotation * Quaternion.Euler(0f, eased * 35f, 0f);
                yield return null;
            }
            if (body != null) Destroy(body.gameObject);
        }

        void UpdateFood(float dt)
        {
            for (int i = food.Count - 1; i >= 0; i--)
            {
                Transform orb = food[i];
                if (orb == null) { food.RemoveAt(i); continue; }
                orb.Rotate(0, 65f * dt, 0);
                orb.position += Vector3.up * Mathf.Sin(Time.time * 2.2f + i) * .0008f;
                if (magnetPowerUpRemaining > 0 && Vector3.Distance(orb.position, player.transform.position) < 18f)
                    orb.position = Vector3.MoveTowards(orb.position, player.transform.position, 13f * dt);
                if (Vector3.Distance(orb.position, player.transform.position) < player.Size * .72f + .5f)
                {
                    int gained = orb.GetComponent<FoodValue>().Value == 2 ? 10 : 4;
                    score += gained;
                    ShowGrowthGain(gained);
                    feedback.CollectFood();
                    Destroy(orb.gameObject);
                    food.RemoveAt(i);
                    int newLevel = score / ScorePerLevel + 1;
                    if (newLevel > player.Level)
                    {
                        player.SetLevel(newLevel);
                        feedback.LevelUp(player.transform.position, player.Size);
                        cameraEmphasisRemaining = .55f;
                        levelFlashRemaining = .72f;
                        shownGrowthProgress = 0f;
                        ShowTip("升到 Lv." + newLevel + "，游得更快、身体更大！");
                        EnsureHunters();
                    }
                    player.SetGrowthProgress((score % ScorePerLevel) / (float)ScorePerLevel);
                    SpawnFood(RandomPoint(34f), Random.value < .12f ? 2 : 1);
                }
            }
        }

        void UpdateMeat(float dt)
        {
            for (int i = meat.Count - 1; i >= 0; i--)
            {
                MeatPickup pickup = meat[i];
                if (pickup == null) { meat.RemoveAt(i); continue; }
                pickup.Tick(dt);
                if (pickup.Age >= MeatPickup.Lifetime ||
                    Vector3.Distance(pickup.transform.position, player.transform.position) > 65f)
                {
                    meat.RemoveAt(i);
                    Destroy(pickup.gameObject);
                    continue;
                }
                if (pickup.Age < .35f ||
                    Vector3.Distance(pickup.transform.position, player.transform.position) >= player.Size * .72f + .42f)
                    continue;

                score += MeatPickup.ScoreValue;
                ShowGrowthGain(MeatPickup.ScoreValue);
                feedback.CollectFood();
                meat.RemoveAt(i);
                Destroy(pickup.gameObject);
                int newLevel = score / ScorePerLevel + 1;
                if (newLevel > player.Level)
                {
                    player.SetLevel(newLevel);
                    feedback.LevelUp(player.transform.position, player.Size);
                    cameraEmphasisRemaining = .55f;
                    levelFlashRemaining = .72f;
                    shownGrowthProgress = 0f;
                    ShowTip("吃到鲜肉！升到 Lv." + newLevel + "！");
                    EnsureHunters();
                }
                player.SetGrowthProgress((score % ScorePerLevel) / (float)ScorePerLevel);
            }
        }

        void UpdatePowerUps(float dt)
        {
            foreach (Transform item in powerUps)
            {
                if (item == null) continue;
                item.Rotate(0, 90f * dt, 0);
                if (Vector3.Distance(item.position, player.transform.position) < player.Size + .7f)
                {
                    switch (item.GetComponent<PowerUpToken>().Kind)
                    {
                        case PowerUpKind.Speed: speedPowerUpRemaining = 7f; ShowTip("加速道具：游得更快！"); break;
                        case PowerUpKind.Magnet: magnetPowerUpRemaining = 9f; ShowTip("吸引道具：附近光点会飞过来！"); break;
                    }
                    Destroy(item.gameObject);
                }
            }
            powerUps.RemoveAll(item => item == null);
        }

        void UpdateSchoolWave(float dt)
        {
            waveTimer -= dt;
            if (waveTimer > 0) return;
            waveTimer = Mathf.Max(26f, 36f - player.Level * .1f);
            int count = Mathf.Min(Random.Range(3, 6), MaximumFishCount - fish.Count);
            Vector3 edge = player.transform.position + new Vector3(Random.Range(-35, 35), 0, Random.value < .5f ? -44 : 44);
            for (int i = 0; i < count; i++)
            {
                var actor = new GameObject("Passing fish school").AddComponent<FishActor>();
                actor.transform.position = edge + new Vector3(i * Random.Range(-1.5f, 1.5f), 0, i * .8f);
                actor.Configure(Mathf.Max(1, player.Level - Random.Range(0, 2)), i % 5 == 0 ? SeaCreatureKind.Shrimp : SeaCreatureKind.Fish, Palette[Random.Range(0, Palette.Length)]);
                fish.Add(actor);
            }
            ShowTip("一群小鱼游过来了！");
        }

        void UpdateHUD(float dt)
        {
            float targetProgress = (score % ScorePerLevel) / (float)ScorePerLevel;
            shownGrowthProgress = Mathf.Lerp(shownGrowthProgress, targetProgress, 1f - Mathf.Exp(-9f * dt));
            growthFill.rectTransform.anchorMax = new Vector2(shownGrowthProgress, 1);
            float pulse = Mathf.Sin(growthPulseRemaining / .45f * Mathf.PI);
            growthFill.color = Color.Lerp(new Color(.70f, .94f, .85f), new Color(1f, .91f, .55f), Mathf.Max(0f, pulse));
            growthFill.rectTransform.localScale = new Vector3(1f, 1f + Mathf.Max(0f, pulse) * .38f, 1f);
            growthMarker.enabled = shownGrowthProgress > .025f;
            growthMarker.rectTransform.anchoredPosition = new Vector2(-150f + shownGrowthProgress * 300f, 0f);
            growthMarker.color = new Color(.83f, 1f, .90f, .42f + Mathf.Max(0f, pulse) * .34f);
            float levelPulse = Mathf.Sin(levelFlashRemaining / .72f * Mathf.PI);
            levelText.color = Color.Lerp(Color.white, new Color(1f, .77f, .38f), Mathf.Max(0f, levelPulse));
            levelText.rectTransform.localScale = Vector3.one * (1f + Mathf.Max(0f, levelPulse) * .09f);
            float gainT = 1f - gainTextRemaining / .65f;
            gainText.rectTransform.anchoredPosition = new Vector2(218f, -22f + gainT * 17f);
            gainText.color = new Color(1f, .86f, .53f, Mathf.Clamp01(gainTextRemaining / .22f));
            uiTimer -= dt;
            if (uiTimer <= 0)
            {
                uiTimer = .1f;
                int progress = score % ScorePerLevel;
                levelText.text = "Lv. " + player.Level;
                scoreText.text = "成长 " + progress + " / " + ScorePerLevel + "  ·  吃鱼 " + eaten;
                if (speedPowerUpRemaining > 0)
                {
                    effectText.text = "加速 · " + Mathf.CeilToInt(speedPowerUpRemaining) + "s";
                    effectText.color = new Color(.56f, .92f, 1f);
                }
                else if (magnetPowerUpRemaining > 0)
                {
                    effectText.text = "吸引光点 · " + Mathf.CeilToInt(magnetPowerUpRemaining) + "s";
                    effectText.color = new Color(.87f, .73f, 1f);
                }
                else if (hazardSlowRemaining > 0)
                {
                    effectText.text = "海胆减速 · " + Mathf.CeilToInt(hazardSlowRemaining) + "s";
                    effectText.color = new Color(1f, .77f, .61f);
                }
                else effectText.text = "";
            }
        }

        void ShowGrowthGain(int amount)
        {
            gainTextAmount = gainTextRemaining > .4f ? gainTextAmount + amount : amount;
            gainText.text = "+" + gainTextAmount;
            gainTextRemaining = .65f;
            growthPulseRemaining = .45f;
        }

        void UpdateSeaMines(float dt)
        {
            for (int i = seaMines.Count - 1; i >= 0; i--)
            {
                Transform mine = seaMines[i];
                if (mine == null) { seaMines.RemoveAt(i); continue; }
                mine.Rotate(0, 28f * dt, 0);
                if (Vector3.Distance(mine.position, player.transform.position) < player.Size + 1.05f)
                {
                    hazardSlowRemaining = 3f;
                    mine.position = SpawnAtSafeDistance(28f, 44f);
                    ShowTip("碰到海胆，短暂减速！");
                }
            }
        }

        void FinishGame()
        {
            if (finished) return;
            finished = true;
            if (chaseEdgeCue != null) chaseEdgeCue.gameObject.SetActive(false);
            ShowTip("被大鱼追上啦！点击屏幕返回");
            StartCoroutine(WaitForExit());
        }

        void ReturnToApp()
        {
            if (finished) return;
            finished = true;
            if (chaseEdgeCue != null) chaseEdgeCue.gameObject.SetActive(false);
#if UNITY_IOS && !UNITY_EDITOR
            ChinsekidFishGameDidFinish(score, player.Level, eaten);
#endif
        }

        System.Collections.IEnumerator WaitForExit()
        {
            yield return new WaitForSeconds(1.2f);
#if UNITY_IOS && !UNITY_EDITOR
            ChinsekidFishGameDidFinish(score, player.Level, eaten);
#endif
            ShowTip("游戏结束 · Lv." + player.Level + " · 吃到 " + eaten + " 条鱼");
        }

        static bool HasFreshExitPress()
        {
            if (Input.touchCount == 0) return Input.GetMouseButtonDown(0);
            for (int i = 0; i < Input.touchCount; i++)
                if (Input.GetTouch(i).phase == TouchPhase.Began) return true;
            return false;
        }

        void ShowTip(string message)
        {
            // Gameplay feedback stays in the top HUD, away from the player.
        }

        Vector3 RandomPoint(float safeRadius = 0)
        {
            Vector3 center = player == null ? Vector3.zero : player.transform.position;
            Vector2 offset = Random.insideUnitCircle * (safeRadius > 0 ? safeRadius : 48f);
            return new Vector3(center.x + offset.x, .2f, center.z + offset.y);
        }

        Vector3 SpawnAtSafeDistance(float minimum, float maximum)
        {
            Vector2 direction = Random.insideUnitCircle.normalized;
            float distance = Random.Range(minimum, maximum);
            Vector3 center = player == null ? Vector3.zero : player.transform.position;
            return new Vector3(center.x + direction.x * distance, .2f, center.z + direction.y * distance);
        }

        static void KeepInWorld(Transform item)
        {
            item.position = new Vector3(item.position.x, .2f, item.position.z);
        }

        static Material MakeMaterial(Color color, float metallic)
        {
            var material = new Material(Resources.Load<Material>("FishSurface")) { color = color };
            if (material.HasProperty("_Metallic")) material.SetFloat("_Metallic", metallic);
            return material;
        }

        static GameObject AddPanel(Transform parent, string name, Vector2 anchor, Vector2 size, Vector2 position, Color color)
        {
            var panel = new GameObject(name, typeof(RectTransform), typeof(Image));
            panel.transform.SetParent(parent, false);
            var rect = panel.GetComponent<RectTransform>();
            rect.anchorMin = rect.anchorMax = anchor;
            rect.sizeDelta = size;
            rect.anchoredPosition = position;
            panel.GetComponent<Image>().color = color;
            return panel;
        }

        static Text AddText(Transform parent, string value, int size, FontStyle style, Vector2 position, Vector2 dimensions, Color color)
        {
            var textObject = new GameObject("Text", typeof(RectTransform), typeof(Text));
            textObject.transform.SetParent(parent, false);
            var rect = textObject.GetComponent<RectTransform>();
            rect.anchorMin = rect.anchorMax = new Vector2(.5f, .5f);
            rect.anchoredPosition = position;
            rect.sizeDelta = dimensions;
            var label = textObject.GetComponent<Text>();
            label.text = value;
            label.font = Font.CreateDynamicFontFromOSFont(new[] { "PingFang SC", "PingFang", "Arial" }, size);
            label.fontSize = size;
            label.fontStyle = style;
            label.color = color;
            label.alignment = TextAnchor.MiddleCenter;
            label.horizontalOverflow = HorizontalWrapMode.Overflow;
            label.raycastTarget = false;
            var outline = textObject.AddComponent<Outline>();
            outline.effectColor = new Color(.025f, .12f, .17f, .6f);
            outline.effectDistance = new Vector2(1, -1);
            return label;
        }

        void OnDestroy()
        {
            if (hudShapeSprite != null) Destroy(hudShapeSprite);
            if (hudShapeTexture != null) Destroy(hudShapeTexture);
            if (hudGlowSprite != null) Destroy(hudGlowSprite);
            if (hudGlowTexture != null) Destroy(hudGlowTexture);
            if (chaseCueSprite != null) Destroy(chaseCueSprite);
            if (chaseCueTexture != null) Destroy(chaseCueTexture);
        }

        sealed class FoodValue : MonoBehaviour { public int Value = 1; }
        sealed class PowerUpToken : MonoBehaviour { public PowerUpKind Kind; }
    }

    sealed class FishBoostHold : MonoBehaviour, IPointerDownHandler, IPointerUpHandler, IPointerExitHandler
    {
        FishGameManager manager;
        int? heldPointerId;
        public void Initialize(FishGameManager game) => manager = game;
        public void OnPointerDown(PointerEventData eventData)
        {
            if (heldPointerId.HasValue) return;
            heldPointerId = eventData.pointerId;
            manager.SetBoosting(true);
        }
        public void OnPointerUp(PointerEventData eventData) => Release(eventData.pointerId);
        public void OnPointerExit(PointerEventData eventData) => Release(eventData.pointerId);
        void Release(int pointerId)
        {
            if (heldPointerId != pointerId) return;
            ResetBoost();
        }
        void OnDisable() => ResetBoost();
        void OnApplicationFocus(bool focused) { if (!focused) ResetBoost(); }
        void OnApplicationPause(bool paused) { if (paused) ResetBoost(); }
        void ResetBoost()
        {
            heldPointerId = null;
            if (manager != null) manager.SetBoosting(false);
        }
    }

}
