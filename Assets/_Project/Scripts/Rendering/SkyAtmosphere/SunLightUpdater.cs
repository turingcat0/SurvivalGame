using System;
using TuringCat.Rendering.SkyAtomshpere;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

/// <summary>
/// Reads one texel from the global TransmittanceLUT via async GPU readback
/// and uses it to drive the directional light's colour and intensity,
/// mirroring the way the PBRSkybox shader tints the sun disc.
/// </summary>
public static class SunLightUpdater
{
    // ── LUT dimensions (must match SkyAtmosphereRenderFeaturePass) ──
    private const int TransmittanceLutWidth = 256;
    private const int TransmittanceLutHeight = 64;

    private static bool _readbackPending;
    private static float _lastVisibility = 1f;

    // ── Transmittance LUT UV helpers (mirrors SkyAtmosphereCommon.hlsl exactly) ──

    static float SafeSqrt(float x) => Mathf.Sqrt(Mathf.Max(x, 0f));
    static float ClampCosine(float mu) => Mathf.Clamp(mu, -1f, 1f);

    static float GetTextureCoordFromUnitRange(float x, int textureSize)
    {
        float n = textureSize;
        return 0.5f / n + x * (1f - 1f / n);
    }

    static float DistanceToTopAtmosphereBoundary(float topRadius, float r, float mu)
    {
        float discriminant = r * r * (mu * mu - 1f) + topRadius * topRadius;
        return Mathf.Max(-r * mu + SafeSqrt(discriminant), 0f);
    }

    /// <summary>
    /// C# port of the visibility calculation from GetTransmittanceToSun
    /// in SkyAtmosphereLutGen.compute. Uses a smoothstep across the sun's
    /// angular radius at the geometric horizon to produce a soft fade
    /// instead of a hard cutoff.
    /// </summary>
    static float GetSunVisibility(float bottomRadius, float r, float mu, float sunAngularRadius)
    {
        float sinThetaH = Mathf.Clamp01(bottomRadius / r);
        float cosThetaH = -Mathf.Sqrt(Mathf.Max(0f, 1f - sinThetaH * sinThetaH));
        float edge0 = -sinThetaH * sunAngularRadius;
        float edge1 =  sinThetaH * sunAngularRadius;
        float x = mu - cosThetaH;
        // Smoothstep
        float t = Mathf.Clamp01((x - edge0) / (edge1 - edge0 + 1e-10f));
        return t * t * (3f - 2f * t);
    }

    /// <summary>
    /// C# port of GetTransmittanceTextureUvFromRMu from SkyAtmosphereCommon.hlsl.
    /// Given (r, mu), returns the UV for sampling the TransmittanceLUT.
    /// </summary>
    public static Vector2 GetTransmittanceUV(float bottomRadius, float topRadius, float r, float mu)
    {
        mu = ClampCosine(mu);

        float H = SafeSqrt(topRadius * topRadius - bottomRadius * bottomRadius);
        float rho = SafeSqrt(r * r - bottomRadius * bottomRadius);

        float d = DistanceToTopAtmosphereBoundary(topRadius, r, mu);
        float dMin = topRadius - r;
        float dMax = rho + H;

        const float kEps = 1e-6f;
        float inv = 1f / Mathf.Max(dMax - dMin, kEps);

        float xMu = Mathf.Clamp01((d - dMin) * inv);
        float xR  = Mathf.Clamp01(rho / Mathf.Max(H, kEps));

        float u = GetTextureCoordFromUnitRange(xMu, TransmittanceLutWidth);
        float v = GetTextureCoordFromUnitRange(xR, TransmittanceLutHeight);
        return new Vector2(u, v);
    }

    /// <summary>
    /// Kicks an async GPU readback for a single texel from the TransmittanceLUT,
    /// then uses the result to tint &amp; attenuate the directional sun light.
    /// Call this once per frame after the TransmittanceLUT compute pass.
    /// </summary>
    public static void RequestReadback(RenderTexture transmittanceLutRT, Vector3 sunDirection, float cameraWorldY)
    {
        var sky = SkyAtmosphere.Instance;
        if (sky == null || sky.sun == null || transmittanceLutRT == null) return;

        // r = distance from planet centre (km)
        float r = sky.bottom + cameraWorldY / 1000f;
        // mu = cos(zenith angle of the sun) = sunDir.y in Y-up
        float mu = sunDirection.y;

        // Compute the smooth horizon visibility (mirrors GetTransmittanceToSun in the compute shader).
        // This MUST run before the _readbackPending check so that fully-occluded
        // state is applied immediately every frame, preventing flicker from stale
        // async readback results arriving while the sun is below the horizon.
        // We multiply the angular radius to artificially slow down the transition 
        // in C# compared to the visually correct sun disc in the shader.
        _lastVisibility = GetSunVisibility(sky.bottom, r, mu, sky.sunAngularRadius * 10.0f);

        // If fully occluded, force intensity to 0 immediately and skip readback
        if (_lastVisibility < 1e-6f)
        {
            sky.sun.intensity = 0f;
            return;
        }

        if (_readbackPending) return;

        Vector2 uv = GetTransmittanceUV(sky.bottom, sky.top, r, mu);

        // Pixel coordinate in the LUT
        int px = Mathf.Clamp(Mathf.FloorToInt(uv.x * TransmittanceLutWidth),  0, TransmittanceLutWidth  - 1);
        int py = Mathf.Clamp(Mathf.FloorToInt(uv.y * TransmittanceLutHeight), 0, TransmittanceLutHeight - 1);

        _readbackPending = true;

        AsyncGPUReadback.Request(
            transmittanceLutRT,
            0, // mip
            px, 1, py, 1, 0, 1,
            // The LUT is R16G16B16A16_SFloat (8 bytes/pixel) but Color is
            // 4×float32 (16 bytes/pixel). Request format conversion so that
            // GetData<Color>() returns the correct values.
            GraphicsFormat.R32G32B32A32_SFloat,
            OnReadbackComplete);
    }

    // UE5 Working Color Space (ACEScg/AP1) back to sRGB.
    static readonly Matrix4x4 ACEScg_to_sRGB = new Matrix4x4(
        new Vector4(1.7050f, -0.1303f, -0.0240f, 0f), // col 0
        new Vector4(-0.6218f, 1.1407f, -0.1290f, 0f), // col 1
        new Vector4(-0.0832f, -0.0104f, 1.1530f, 0f), // col 2
        new Vector4(0f, 0f, 0f, 1f) // col 3
    );

    private static void OnReadbackComplete(AsyncGPUReadbackRequest request)
    {
        _readbackPending = false;

        if (request.hasError) return;

        var sky = SkyAtmosphere.Instance;
        if (sky == null || sky.sun == null) return;

        // After format conversion, the data is R32G32B32A32_SFloat = Color (float4)
        NativeArray<Color> pixels = request.GetData<Color>();
        if (pixels.Length == 0) return;

        Color trans = pixels[0];

        // The transmittance acts as the color of a white sun.
        // Since LUTs are now computed in ACEScg working color space (like UE5), we must convert it back to sRGB.
        Vector3 transWorking = new Vector3(trans.r, trans.g, trans.b);
        Vector3 transSRGB = ACEScg_to_sRGB.MultiplyVector(transWorking);
        transSRGB.x = Mathf.Max(0f, transSRGB.x);
        transSRGB.y = Mathf.Max(0f, transSRGB.y);
        transSRGB.z = Mathf.Max(0f, transSRGB.z);

        sky.sun.color = new Color(transSRGB.x, transSRGB.y, transSRGB.z, 1f).gamma;
        sky.sun.intensity = sky.maxLightIntensity * _lastVisibility;
    }
}
