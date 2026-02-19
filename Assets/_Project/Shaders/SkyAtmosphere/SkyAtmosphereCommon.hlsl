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

struct SkyAtmosphereParameters
{
    float4 atmospherePositionPacked; // bottom_radius, top_radius, unused, unused
    float4 sunParameterPacked; // sunDirectionX, sunDirectionY, sunDirectionZ, sunAngularRadius (Y-up)

    float4 densityProfilePacked; // rayleigh_expScale, mie_expScale, ozone_center, ozone_half_width

    float4 rayleighScattering;
    float4 mieScatteringPacked; // mieScatteringR, mieScatteringG, mieScatteringB, mie_phase_function_g
    float4 mieAbsorption;
    float4 ozoneAbsorption;
};



float GetRayleighIntensity(in SkyAtmosphereParameters skyAtmosphere, in float altitude)
{
    return exp(-altitude * skyAtmosphere.densityProfilePacked.x);
}

float GetMieIntensity(in SkyAtmosphereParameters skyAtmosphere, in float altitude)
{
    return exp(-altitude * skyAtmosphere.densityProfilePacked.y);
}

float GetOzoneIntensity(in SkyAtmosphereParameters skyAtmosphere, in float altitude)
{
    return max(0, 1 - abs(altitude - skyAtmosphere.densityProfilePacked.z) / skyAtmosphere.densityProfilePacked.w);
}

// Remap u from [0, 1] to [-1, 1]
float GetUnitRange(float u)
{
    return (u - 0.5f) * 2;
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



#endif