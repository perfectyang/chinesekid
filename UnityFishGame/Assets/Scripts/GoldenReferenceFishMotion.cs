using UnityEngine;

namespace Chinsekid.FishGame
{
    public sealed class GoldenReferenceFishMotion : MonoBehaviour
    {
        public Transform tail;
        public Transform leftFin;
        public Transform rightFin;
        float phase;
        float cadence = 6f;
        public void SetFast(bool fast) => cadence = fast ? 11f : 6f;
        void Awake() => phase = Random.value * Mathf.PI * 2;
        void Update()
        {
            phase += Time.deltaTime * cadence;
            if (tail != null) tail.localRotation = Quaternion.Euler(0, Mathf.Sin(phase) * 22f, 0);
            if (leftFin != null) leftFin.localRotation = Quaternion.Euler(0, -25 + Mathf.Sin(phase + .7f) * 13f, -16);
            if (rightFin != null) rightFin.localRotation = Quaternion.Euler(0, 25 - Mathf.Sin(phase + .7f) * 13f, 16);
        }
    }
}
