/**
 * Copyright (c) 2017 Eric Bruneton
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holders nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Precomputed Atmospheric Scattering
 * Copyright (c) 2008 INRIA
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holders nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef SKY_ATMOSPHERE_COMMON_H
#define SKY_ATMOSPHERE_COMMON_H
#include "../Common.hlsl"

struct SkyAtmosphereParameters
{
    float4 atmospherePositionPacked; // bottom_radius, top_radius, unused, unused
    float4 sunParameterPacked; // sunAzimuth, camY, unused, sunAngularRadius (Y-up)

    float4 densityProfilePacked; // rayleigh_expScale, mie_expScale, ozone_center, ozone_half_width

    float4 rayleighScattering;
    float4 mieScatteringPacked; // mieScatteringR, mieScatteringG, mieScatteringB, mie_phase_function_g
    float4 mieAbsorption;
    float4 ozoneAbsorption;
    float4 groundAlbedo;
};


float GetRayleighIntensity(in SkyAtmosphereParameters skyAtmosphere, in float altitude)
{
    return exp(-altitude * skyAtmosphere.densityProfilePacked.x);
}

float GetMieIntensity(in SkyAtmosphereParameters skyAtmosphere, in float altitude)
{
    return exp(-altitude * skyAtmosphere.densityProfilePacked.y);
}

float GetPhaseG(in SkyAtmosphereParameters skyAtmosphere)
{
    return skyAtmosphere.mieScatteringPacked.w;
}
float GetOzoneIntensity(in SkyAtmosphereParameters skyAtmosphere, in float altitude)
{
    return max(0, 1 - abs(altitude - skyAtmosphere.densityProfilePacked.z) / skyAtmosphere.densityProfilePacked.w);
}

float3 GetGroundAlbedo(in SkyAtmosphereParameters skyAtmosphere)
{
    return skyAtmosphere.groundAlbedo.xyz;
}

float GetSunAngular(in SkyAtmosphereParameters skyAtmosphere)
{
    return skyAtmosphere.sunParameterPacked.w;
}

float GetCameraY(in SkyAtmosphereParameters skyAtmosphere)
{
    return skyAtmosphere.sunParameterPacked.y;
}

float GetTextureCoordFromUnitRange(float x, int textureSize)
{
    float n = (float)textureSize;
    return 0.5 / n + x * (1.0 - 1.0 / n);
}

float GetUnitRangeFromTextureCoord(float u, int textureSize)
{
    float n = (float)textureSize;
    return (u - 0.5 / n) / (1.0 - 1.0 / n);
}

float DistanceToTopAtmosphereBoundary(float topRadius, float r, float mu)
{
    float discriminant = r * r * (mu * mu - 1.0) + topRadius * topRadius;
    return max(-r * mu + SafeSqrt(discriminant), 0.0);
}

float DistanceToBottomAtmosphereBoundary(float bottomRadius, float r, float mu)
{
    float discriminant = r * r * (mu * mu - 1.0) +
        bottomRadius * bottomRadius;
    return max(-r * mu - SafeSqrt(discriminant), 0.0);
}

// (r, mu) -> uv
float2 GetTransmittanceTextureUvFromRMu(
    float bottomRadius, float topRadius,
    float r, float mu,
    int transmittanceWidth, int transmittanceHeight)
{
    mu = ClampCosine(mu);

    float H = SafeSqrt(topRadius * topRadius - bottomRadius * bottomRadius);

    float rho = SafeSqrt(r * r - bottomRadius * bottomRadius);

    float d = DistanceToTopAtmosphereBoundary(topRadius, r, mu);

    float d_min = topRadius - r;
    float d_max = rho + H;

    float inv = 1.0 / max(d_max - d_min, kEps);

    float x_mu = (d - d_min) * inv;
    float x_r = rho / max(H, kEps);

    x_mu = saturate(x_mu);
    x_r = saturate(x_r);

    float u = GetTextureCoordFromUnitRange(x_mu, transmittanceWidth);
    float v = GetTextureCoordFromUnitRange(x_r, transmittanceHeight);
    return float2(u, v);
}

// uv -> (r, mu)
void GetRMuFromTransmittanceTextureUv(
    float bottomRadius, float topRadius,
    float2 uv,
    int transmittanceWidth, int transmittanceHeight,
    out float r, out float mu)
{
    float x_mu = GetUnitRangeFromTextureCoord(uv.x, transmittanceWidth);
    float x_r = GetUnitRangeFromTextureCoord(uv.y, transmittanceHeight);

    x_mu = saturate(x_mu);
    x_r = saturate(x_r);

    float H = SafeSqrt(topRadius * topRadius - bottomRadius * bottomRadius);

    float rho = H * x_r;
    r = SafeSqrt(rho * rho + bottomRadius * bottomRadius);

    float d_min = topRadius - r;
    float d_max = rho + H;
    float d = d_min + x_mu * (d_max - d_min);

    if (d < kEps)
    {
        mu = 1.0;
    }
    else
    {
        // mu = (H^2 - rho^2 - d^2) / (2 r d)
        mu = (H * H - rho * rho - d * d) / (2.0 * r * d);
        mu = ClampCosine(mu);
    }
}

float GetAtmosphereBottom(in SkyAtmosphereParameters skyAtmosphere)
{
    return skyAtmosphere.atmospherePositionPacked.x;
}

float GetAtmosphereTop(in SkyAtmosphereParameters skyAtmosphere)
{
    return skyAtmosphere.atmospherePositionPacked.y;
}


float GetAtmosphereHeight(in SkyAtmosphereParameters skyAtmosphere)
{
    return skyAtmosphere.atmospherePositionPacked.y - skyAtmosphere.atmospherePositionPacked.x;
}

float3 FibonacciSphereDir(uint i, uint N)
{
    // i in [0, N-1]
    float phi = 3.14159265f * (3.0f - sqrt(5.0f)); // golden angle ~2.399963...
    float y = 1.0f - 2.0f * ((i + 0.5f) / N); // (-1, 1)
    float r = sqrt(max(0.0f, 1.0f - y * y));
    float theta = phi * i;

    float x = cos(theta) * r;
    float z = sin(theta) * r;
    return float3(x, y, z);
}

bool RayIntersectsGround(in SkyAtmosphereParameters skyAtmosphere, float r, float mu)
{
    return mu < 0.0 && r * r * (mu * mu - 1.0) +
        GetAtmosphereBottom(skyAtmosphere) * GetAtmosphereBottom(skyAtmosphere) >= 0.0;
}

float RayleighPhase(float cosTheta)
{
    return (3.0f / (16.0f * PI)) * (1 + cosTheta * cosTheta);
}

float MiePhase(float cosTheta, float g)
{
    return (3.0f / (8.0f * PI)) * (1 - g * g) * (1 + cosTheta * cosTheta) / ((2 + g * g) * pow(
        1 + g * g - 2 * g * cosTheta, 1.5f));
}

#endif
