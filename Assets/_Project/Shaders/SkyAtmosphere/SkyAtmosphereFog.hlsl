#ifndef SKY_ATMOSPHERE_FOG_H
#define SKY_ATMOSPHERE_FOG_H

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "SkyAtmosphereCommon.hlsl"

TEXTURE3D(_AerialPerspectiveLut);
SAMPLER(sampler_AerialPerspectiveLut);
float _FogScale;

#define SKY_ATMOSPHERE_INIT_FOG(o, v) o.vertexFog = GetAerialPerspectiveFogVertex(v.positionNDC, v.positionWS);
#define SKY_ATMOSPHERE_FOG_COORD(i) float4 vertexFog : TEXCOORD##i
#define SKY_ATMOSPHERE_APPLY_FOG(v, c) c.xyz = ApplyAerialPerspective(c.xyz, v.vertexFog);

float4 GetAerialPerspectiveFogVertex(float4 positionNDC, float3 positionWS)
{
    float2 screenUV = positionNDC.xy / positionNDC.w;

    float distKm = length(positionWS - GetCameraPositionWS()) / 1000.0f;

    float zSlice = saturate(GetFogSliceFromDistance(distKm, _FogScale));

    float4 fog = SAMPLE_TEXTURE3D_LOD(_AerialPerspectiveLut, sampler_AerialPerspectiveLut, float3(screenUV, zSlice), 0);

    return fog;
}

float3 ApplyAerialPerspective(float3 objectColor, float4 vertexFog)
{
    float3 fogColorSrgb = ConvertColor_Working_to_sRGB(vertexFog.rgb);
    return objectColor * vertexFog.a + fogColorSrgb;
}
#endif
