#ifndef COMMON_H
#define COMMON_H

float rand(float2 st)
{
    // Simple hash-based noise; used for pseudo-random wind variation.
    return frac(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453);
}

inline float3 vertexAnimation(float3 worldPos, float4 vertex, half4 color, float scale)
{
    // Wind sway animation driven by vertex color.r as weight and world-position-based noise.
    float t1 = _Time.y + (worldPos.x * 0.6) - (worldPos.y * 0.6) - (worldPos.z * 0.8);
    float t2 = _Time.y + (worldPos.x * 2) + (worldPos.z * 3);

    float randNoise = rand(float2((worldPos.x * 0.8), (worldPos.z * 0.8)));

    float x = 1.44 * pow(cos(t1 / 2), 2) + sin(t1 / 2) * randNoise;
    float y = (2 * sin(3 * x) + sin(10 * x) - cos(5 * x)) / 10 * randNoise;

    float3 move = float3(0, 0, 0);
    move.x = lerp(0, y, color.r) / 2 * scale;
    move.y = lerp(0, y, color.r) / 4 * scale;
    move.z = lerp(0, sin(t2) * cos(2 * t2) * scale / 10, color.r);

    return move;
}


float3 RotateAroundAxis(float3 v, float3 axis, float angle)
{
    float s, c;
    sincos(angle, s, c);
    return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

#endif
