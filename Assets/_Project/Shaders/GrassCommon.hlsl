#ifndef GRASS_COMMON_H
#define GRASS_COMMON_H
#include "Common.hlsl"

TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);
TEXTURE2D(_NormalMap);
SAMPLER(sampler_NormalMap);
TEXTURE2D(_TransMap);
SAMPLER(sampler_TransMap);
TEXTURE2D(_SpecMap);
SAMPLER(sampler_SpecMap);

#ifdef USE_INTERACTION
TEXTURE2D(_InteractionRT);
SAMPLER(sampler_InteractionRT);

CBUFFER_START(InteractionProperties)
    float4 _InteractionCenterWS;
    float _InteractionRadius;
    float _InteractionThickness;
CBUFFER_END

#endif


CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _NormalMap_ST;
    float _CutOff;
    float _TransThreshold;
    float _TransStrength;
    float _TransSharpness;
    float _SpecStrength;
    float _SpecShininess;
    float _AnimationScale;
    half4 _TransColor;

    #ifdef USE_INTERACTION
    float _InteractionEffectiveHeight;
    float _InteractionStrength;
    float _InteractionMaxAngle;
    #endif
CBUFFER_END

#ifdef USE_INTERACTION
float4 SampleInteractionWS(float3 ws)
{
    float2 uv = (ws.xz - _InteractionCenterWS.xz) / _InteractionRadius / 2 + 0.5f;

    // Edge Fade
    float2 uvv = 1 - uv;
    float edge = min(min(uv.x, uvv.x), min(uv.y, uvv.y));
    float strength = smoothstep(0, 0.05, edge);

    float4 tex = SAMPLE_TEXTURE2D_LOD(_InteractionRT, sampler_InteractionRT, uv, 0);

    float height = _InteractionCenterWS.y + _InteractionThickness * (tex.z - 0.5f);

    return float4(tex.xy, height, strength);
}

float ApplyInteraction(inout float3 worldPos, in float3 localPos, in float weight)
{
    float3 rootWS = TransformObjectToWorld(float3(0, 0, 0));
    float4 inter = SampleInteractionWS(rootWS);

    float3 bendWS = float3(inter.x, 0, inter.y);
    float bendLen = length(bendWS);

    const float offset = 0.0f;
    float tipW = pow(saturate(weight - offset) / (1 - offset), 2.0f);

    float angle = bendLen * _InteractionStrength * tipW * inter.w;
    angle = min(angle, _InteractionMaxAngle);

    float3 up = float3(0, 1, 0);
    float3 bendDir = (bendLen > 1e-2) ? (bendWS / bendLen) : float3(0, 0, 0);
    float3 axis = cross(up, bendDir);
    float axisLen2 = dot(axis, axis);

    float3 v = worldPos - rootWS;

    angle *= (1 - saturate(dot(v, bendDir)));

    if (axisLen2 > 1e-8 && angle != 0)
    {
        axis *= rsqrt(axisLen2);
        float s = sin(angle);
        float c = cos(angle);
        float3 vRot = v * c + cross(axis, v) * s + axis * dot(axis, v) * (1 - c);

        // make grass smaller
        worldPos = rootWS + vRot * lerp(1.0f, 0.7f, angle / 1.3f);
    }
    return saturate(angle / _InteractionMaxAngle);
}


#endif
#endif
