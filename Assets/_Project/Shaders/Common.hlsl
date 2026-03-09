#ifndef COMMON_H
#define COMMON_H

#ifndef kEps
static const float kEps = 1e-6f;
#endif

#ifndef PI_
static const float PI_ = 3.14159265f;
#endif
// Remap u from [0, 1] to [-1, 1]

float GetUnitRange(float u)
{
    return (u - 0.5f) * 2;
}

float UnitRangeToUV(float unit)
{
    return (unit + 1) / 2.f;
}

// [-1,1] clamp
float ClampCosine(float x)
{
    return clamp(x, -1.0, 1.0);
}

// sqrt(max(x,0))
float SafeSqrt_(float x)
{
    return sqrt(max(x, 0.0));
}
#endif