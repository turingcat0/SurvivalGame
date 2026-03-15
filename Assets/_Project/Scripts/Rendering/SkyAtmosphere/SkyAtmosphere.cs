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
        [Header("Ref")]
        public Light sun;
        [Tooltip("Max intensity for the directional light (independent of sunPower used by shaders)")]
        public float maxLightIntensity = 1.0f;
        [Tooltip("Sun rotation speed in degrees per second")]
        public float sunRotationSpeed = 1.0f;
        [Tooltip("Allow the sun to rotate even when not in Play mode")]
        public bool rotateInEditor = false;

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
        // Dirty flag – set when atmosphere-only params change
        // (Transmittance LUT & Multi-Scattering LUT depend on these)
        // ──────────────────────────────────────────────

        /// <summary>
        /// True when atmosphere optical parameters have changed since the last
        /// time ClearDirty() was called. RenderFeature uses this to decide
        /// whether to re-compute the Transmittance LUT and Multi-Scattering LUT.
        /// </summary>
        public bool AtmosphereParamsDirty { get; private set; } = true;

        /// <summary>Call this after consuming the dirty flag.</summary>
        public void ClearDirty() => AtmosphereParamsDirty = false;

        // Hash of atmosphere-only parameters from the previous frame
        private int _lastAtmosphereHash;

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

            // Force LUT recomputation after domain reload (script recompilation)
            // because GPU textures are destroyed during reload even though
            // the atmosphere parameters themselves haven't changed.
            AtmosphereParamsDirty = true;
        }

        void OnDisable()
        {
            if (Instance == this)
                Instance = null;
        }

        void Update()
        {
            // Rotate the sun around the X axis
            if (sun != null && sunRotationSpeed != 0f && (Application.isPlaying || rotateInEditor))
                sun.transform.Rotate(Vector3.right, sunRotationSpeed * Time.deltaTime, Space.World);

            Shader.SetGlobalFloat(FogScaleProperty, fogScale);

            DynamicGI.UpdateEnvironment();

            // Check whether atmosphere optical parameters changed this frame.
            unchecked
            {
                int hash = 17;
                hash = hash * 31 + bottom.GetHashCode();
                hash = hash * 31 + top.GetHashCode();
                hash = hash * 31 + rayleighScaleHeight.GetHashCode();
                hash = hash * 31 + mieScaleHeight.GetHashCode();
                hash = hash * 31 + ozoneCenter.GetHashCode();
                hash = hash * 31 + ozoneHalfWidth.GetHashCode();
                hash = hash * 31 + rayleighScattering.GetHashCode();
                hash = hash * 31 + mieScattering.GetHashCode();
                hash = hash * 31 + mieAbsorption.GetHashCode();
                hash = hash * 31 + ozoneAbsorption.GetHashCode();
                hash = hash * 31 + miePhaseFunctionG.GetHashCode();
                hash = hash * 31 + groundAlbedo.GetHashCode();

                if (hash != _lastAtmosphereHash)
                {
                    _lastAtmosphereHash = hash;
                    AtmosphereParamsDirty = true;
                }
            }

        }
    }
}