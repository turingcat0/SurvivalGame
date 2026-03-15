using UnityEngine;

namespace TuringCat.Rendering.SkyAtomshpere
{
    /// <summary>
    /// Singleton MonoBehaviour that holds all sky atmosphere parameters.
    /// SkyAtmosphereRenderFeature reads directly from SkyAtmosphere.Instance
    /// instead of storing its own copy of the data.
    /// </summary>
    [ExecuteAlways]
    public class SkyAtmosphere : MonoBehaviour
    {
        // ──────────────────────────────────────────────
        // Singleton
        // ──────────────────────────────────────────────

        public static SkyAtmosphere Instance { get; private set; }

        // ──────────────────────────────────────────────
        // Atmosphere parameters
        // ──────────────────────────────────────────────

        [Header("General")]
        public Color groundAlbedo = new Color(0.1f, 0.1f, 0.1f, 1.0f);
        public float sunPower = 1.0f;

        [Header("Atmosphere Size (km)")]
        public float bottom = 6360.0f;
        public float top = 6420.0f;

        [Header("Density Profile")]
        public float rayleighScaleHeight = 8.0f;
        public float mieScaleHeight = 1.2f;
        public float ozoneCenter = 25.0f;
        public float ozoneHalfWidth = 15.0f;

        [Header("Scattering & Absorption Coefficients")]
        public Vector3 rayleighScattering = new Vector3(5.802e-3f, 13.558e-3f, 33.1e-3f);
        public Vector3 mieScattering = new Vector3(3.996e-3f, 3.996e-3f, 3.996e-3f);
        public Vector3 mieAbsorption = new Vector3(4.40e-3f, 4.40e-3f, 4.40e-3f);
        public Vector3 ozoneAbsorption = new Vector3(0.650e-3f, 1.881e-3f, 0.085e-3f);
        public float miePhaseFunctionG = 0.8f;
        public float sunAngularRadius = 0.00935f / 2.0f;

        [Header("Fog")]
        public float fogScale = 10.0f;

        // ──────────────────────────────────────────────
        // Internal
        // ──────────────────────────────────────────────

        private static readonly int FogScaleProperty = Shader.PropertyToID("_FogScale");

        // ──────────────────────────────────────────────
        // Lifecycle
        // ──────────────────────────────────────────────

        void OnEnable()
        {
            // Register this instance as the singleton
            if (Instance != null && Instance != this)
            {
                Debug.LogWarning("[SkyAtmosphere] Multiple SkyAtmosphere instances detected. Only one should exist.", this);
            }
            Instance = this;
        }

        void OnDisable()
        {
            if (Instance == this)
                Instance = null;
        }

        void Update()
        {
            Shader.SetGlobalFloat(FogScaleProperty, fogScale);
        }
    }
}