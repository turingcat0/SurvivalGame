Shader "TuringCat/Branch"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map", 2D) = "black"
        _NormalMap("Normal Map", 2D) = "bump"

    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "LightMode" = "UniversalForward"
        }

        Pass
        {
            HLSLPROGRAM
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 normalUV : TEXCOORD1;

                float3 tbn0 : TEXCOORD2;
                float3 tbn1 : TEXCOORD3;
                float3 tbn2 : TEXCOORD4;

                float3 positionWS : TEXCOORD5;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _NormalMap_ST;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.normalUV = TRANSFORM_TEX(IN.uv, _NormalMap);

                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.tbn0 = normalInputs.tangentWS;
                OUT.tbn1 = normalInputs.bitangentWS;
                OUT.tbn2 = normalInputs.normalWS;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half4 nTex = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.normalUV);
                half3 tNormal = UnpackNormal(nTex);
                half3 wNormal = TransformTangentToWorld(tNormal, half3x3(IN.tbn0, IN.tbn1, IN.tbn2), true);

                // Lighting
                // Main Light
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                half3 l = normalize(mainLight.direction);
                half4 finalCol = 0;

                // diffuse
                half3 ndl = saturate(dot(wNormal, l));
                finalCol.xyz += color * ndl * mainLight.color * mainLight.shadowAttenuation;


                //Additional Light
                int addCount = GetAdditionalLightsCount();
                for (int i = 0; i < addCount; ++i)
                {
                    Light addLight = GetAdditionalLight(i, IN.positionWS);
                    half3 addLightDir = normalize(addLight.direction);
                    half3 addNdL = saturate(dot(addLightDir, wNormal));

                    finalCol.xyz += color * addNdL * addLight.color * addLight.distanceAttenuation * addLight.shadowAttenuation;
                }


                finalCol.a = 1;
                return finalCol;
            }
            ENDHLSL
        }
    }
}