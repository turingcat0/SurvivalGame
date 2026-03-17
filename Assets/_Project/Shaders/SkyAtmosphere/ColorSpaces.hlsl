#ifndef COLOR_SPACES_INCLUDED
#define COLOR_SPACES_INCLUDED

// UE5 Working Color Space is ACES AP1 (ACEScg) by default.
// Matrices for Color Space Conversions: sRGB <-> ACEScg (AP1)

#define sRGB_2_ACEScg float3x3( \
    0.6131, 0.3395, 0.0474, \
    0.0702, 0.9164, 0.0134, \
    0.0206, 0.1096, 0.8698 \
)

#define ACEScg_2_sRGB float3x3( \
    1.7050, -0.6218, -0.0832, \
    -0.1303,  1.1407, -0.0104, \
    -0.0240, -0.1290,  1.1530 \
)

// Basic Color Transformations (Linear)
inline float3 ConvertColor_sRGB_to_Working(float3 color_sRGB)
{
    return color_sRGB;
    return mul(sRGB_2_ACEScg, color_sRGB);
}

inline float3 ConvertColor_Working_to_sRGB(float3 color_Working)
{
    return color_Working;
    return mul(ACEScg_2_sRGB, color_Working);
}

// Coefficient Transformations (Non-Linear)
// Exact match to UE5's ConvertCoefficientsFromSRGBToWorkingColorSpace
inline float3 ConvertCoefficients_sRGB_to_Working(float3 coeff_sRGB)
{
    return coeff_sRGB;
    // 1. Convert extinction to transmittance
    float3 transmittance = exp(-coeff_sRGB);
    
    // 2. Transform transmittance to new color space
    transmittance = ConvertColor_sRGB_to_Working(transmittance);
    
    // 3. Convert back to extinction
    return -log(max(transmittance, 1e-5));
}

#endif
