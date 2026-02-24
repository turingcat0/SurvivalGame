static const float kEps = 1e-6;
static const float PI = 3.14159265358979323846;
// Remap u from [0, 1] to [-1, 1]

float GetUnitRange(float u)
{
    return (u - 0.5f) * 2;
}

// [-1,1] clamp
float ClampCosine(float x)
{
    return clamp(x, -1.0, 1.0);
}

// sqrt(max(x,0))
float SafeSqrt(float x)
{
    return sqrt(max(x, 0.0));
}