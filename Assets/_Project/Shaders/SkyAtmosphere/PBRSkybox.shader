Shader "TuringCat/SkyAtmosphere/Skybox"
{
    Properties
    {
        _MoonColor("Moon Color", Color) = (0.5, 0.5, 0.5, 1)
    }
    SubShader
    {
        Tags
        {
            "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox"
        }
        Cull Off ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #include "SkyAtmosphereCommon.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 viewDirOS : TEXCOORD0;
            };

            TEXTURE2D(_SkyViewLut);
            SAMPLER(sampler_SkyViewLut);
            TEXTURE2D(_TransmittanceLut);
            SAMPLER(sampler_TransmittanceLut);
            float3 _MoonColor;

            StructuredBuffer<SkyAtmosphereParameters> _SkyAtmosphereParametersBuffer;

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.viewDirOS = input.positionOS.xyz;
                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                float3 V = normalize(input.viewDirOS);
                SkyAtmosphereParameters params = _SkyAtmosphereParametersBuffer[0];

                float azimuth = atan2(V.z, V.x);;
                float u = azimuth / (2.0 * PI) + 0.5;
                float mu = V.y;
                float latitude = asin(clamp(mu, -1.0, 1.0));
                float v = GetSkyViewTextureVFromL(latitude);

                float3 skyColor = SAMPLE_TEXTURE2D(_SkyViewLut, sampler_SkyViewLut, float2(u, v)).rgb;

                float3 sunDir = params.sunParameterPacked.xyz;
                float sunAngularRadius = params.sunParameterPacked.w;

                float cosTheta = dot(V, sunDir);
                float cosSunRadius = cos(sunAngularRadius);

                float sunDisk = smoothstep(cosSunRadius - 0.0001, cosSunRadius + 0.0001, cosTheta);

                if (sunDisk > 0.0)
                {
                    float r = GetAtmosphereBottom(params) + GetCameraY(params);

                    if (!RayIntersectsGround(params, r, mu))
                    {
                        float2 transUV = GetTransmittanceTextureUvFromRMu(
                            GetAtmosphereBottom(params), GetAtmosphereTop(params),
                            r, mu,
                            256, 64
                        );
                        float3 transmittance = SAMPLE_TEXTURE2D(_TransmittanceLut, sampler_TransmittanceLut, transUV).
xyz;

                        float3 sunLuminance = float3(1.0, 1.0, 1.0) * GetSunPower(params);

                        float3 finalSunColor = sunLuminance * transmittance * sunDisk;

                        skyColor += finalSunColor;
                    }
                }

                 float cosMoonRadius = cos(sunAngularRadius * 1.2f);
                float3 moonDir = -sunDir;
                float cosThetaMoon = dot(V, moonDir);
                float moonDisk = smoothstep(cosMoonRadius - 0.0001, cosMoonRadius + 0.0001, cosThetaMoon);

                if (moonDisk > 0.0)
                {
                    float r = GetAtmosphereBottom(params) + GetCameraY(params);
                    if (!RayIntersectsGround(params, r, mu))
                    {
                        float horizonFade = smoothstep(0.02, 0.5, V.y);
                        skyColor += _MoonColor * moonDisk * horizonFade;
                    }
                }

                skyColor = ConvertColor_Working_to_sRGB(skyColor);
                return float4(skyColor, 1.0);
            }
            ENDHLSL
        }
    }
}