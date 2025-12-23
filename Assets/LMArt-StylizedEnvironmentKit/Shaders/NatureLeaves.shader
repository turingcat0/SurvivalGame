//--------------------------------------------
// Stylized Environment Kit - URP rewrite
//--------------------------------------------

Shader "LMArtShader/NatureLeaves"
{
    Properties
    {
        [NoScaleOffset] _AlbedoTex("Albedo Tex", 2D) = "white" {}
        _CutOff("Alpha Cutoff", Range(0,1)) = 0.5

        [NoScaleOffset]_NormalMap("Normal Map", 2D) = "bump" {}
        _NormalScale("Normal Scale", Range(0,1)) = 1.0

        [Space(16)][Header(Aninmation)]
        [Space(7)]
        [Toggle(USE_VA)]_UseAnimation("Use Animation", Float) = 1.0
        _AnimationScale("Animation Scale", Range(0,1)) = 1.0

        [Space(16)][Header(Back Leaf)]
        [Space(7)]
        [HDR]_TransColor("BackLeaf Color", Color) = (1, 1, 1, 1)
        [NoScaleOffset]_TransTex("BackLeaf ColorTex", 2D) = "white" {}
        _TransArea("BackLeaf Range", Range(0.01,1)) = 0.5
        _TransPower("Translucent Scale", Range(0,1)) = 1.0

        [Space(16)][Header(Specular)]
        [Space(7)]
        [Toggle(USE_SP)]_UseSpecular("Use Specular", Float) = 1.0
        [HDR]_SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
        [NoScaleOffset]_SpecularTex("Specular ColorTex", 2D) = "white" {}
        _Shininess("Shininess", Range(1,96)) = 12
        _SpecularPower("Specular Power", Range(0,3)) = 1.0

        [Space(16)][Header(Shadow)]
        [Space(7)]
        _ShadowIntensity("Shadow Intensity", Range(0,1)) = 1.0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" = "AlphaTest"
            "RenderType" = "TransparentCutout"
        }

        Cull Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

        TEXTURE2D(_AlbedoTex);      SAMPLER(sampler_AlbedoTex);
        TEXTURE2D(_NormalMap);      SAMPLER(sampler_NormalMap);
        TEXTURE2D(_TransTex);       SAMPLER(sampler_TransTex);
        TEXTURE2D(_SpecularTex);    SAMPLER(sampler_SpecularTex);

        CBUFFER_START(UnityPerMaterial)
            half _CutOff;
            half _NormalScale;
            half _UseAnimation;
            half _AnimationScale;
            half4 _TransColor;
            half _TransArea;
            half _TransPower;
            half _UseSpecular;
            half4 _SpecularColor;
            half _Shininess;
            half _SpecularPower;
            half _ShadowIntensity;
        CBUFFER_END

        inline float rand(float2 st)
        {
            return frac(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453);
        }

        inline float3 VertexAnimation(float3 worldPos, float4 vertex, half4 color)
        {
            float t1 = _Time.y + (worldPos.x * 0.6) - (worldPos.y * 0.6) - (worldPos.z * 0.8);
            float t2 = _Time.y + (worldPos.x * 2) + (worldPos.z * 3);

            float randNoise = rand(float2((worldPos.x * 0.8), (worldPos.z * 0.8)));

            float x = 1.44 * pow(cos(t1 / 2), 2) + sin(t1 / 2) * randNoise;
            float y = (2 * sin(3 * x) + sin(10 * x) - cos(5 * x)) / 10 * randNoise;

            float3 move = float3(0, 0, 0);
            move.x = lerp(0, y, color.r) / 2 * _AnimationScale;
            move.y = lerp(0, y, color.r) / 4 * _AnimationScale;
            move.z = lerp(0, sin(t2) * cos(2 * t2) * _AnimationScale / 10, color.r);

            return move;
        }

        inline half3 TransformTangentToWorld(half3 n, float3x3 t2w, half facing)
        {
            half3 worldN = normalize(mul(n, t2w));
            worldN = lerp(-worldN, worldN, step(0, facing));
            return worldN;
        }

        inline half3 SampleNormal(TEXTURE2D_PARAM(map, samplerMap), float2 uv, half scale)
        {
            return UnpackNormalScale(SAMPLE_TEXTURE2D(map, samplerMap, uv), scale);
        }

        inline half3 SampleBakedGI(float2 lightmapUV, float2 dynamicUV, half3 normalWS)
        {
        #ifdef LIGHTMAP_ON
            return SampleLightmap(lightmapUV, dynamicUV, normalWS);
        #else
            return SampleSH(normalWS);
        #endif
        }

        inline half3 EvaluateLight(Light light, half3 normalWS, half3 viewDirWS, half3 albedo, half3 transTex, half3 specTex)
        {
            half NdotL = saturate(dot(normalWS, light.direction));
            half back = saturate(dot(-normalWS, light.direction));
            back = smoothstep(_TransArea, 1, back);
            half atten = light.distanceAttenuation * light.shadowAttenuation;

            half3 diffuse = albedo * (NdotL * light.color * atten);
            half3 trans = _TransPower * _TransColor.rgb * transTex * back * atten * light.color;

            half3 specular = 0;
        #ifdef USE_SP
            half3 h = SafeNormalize(light.direction + viewDirWS);
            half nh = saturate(dot(normalWS, h));
            half specTerm = pow(nh, _Shininess) * _SpecularPower;
            specular = specTerm * _SpecularColor.rgb * specTex * atten * light.color;
        #endif

            return diffuse + trans + specular;
        }
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma shader_feature _ USE_VA
            #pragma shader_feature _ USE_SP
            #pragma multi_compile_instancing

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float4 texcoord   : TEXCOORD0;
                float4 color      : COLOR;
                float2 lightmapUV : TEXCOORD1;
                float2 dynamicUV  : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS   : TEXCOORD2;
                float3 tangentWS  : TEXCOORD3;
                float3 bitangentWS: TEXCOORD4;
                float4 color      : COLOR0;
                float4 shadowCoord: TEXCOORD5;
                float fogFactor   : TEXCOORD6;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 7);
                float2 dynamicUV  : TEXCOORD8;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float3 worldPos = TransformObjectToWorld(input.positionOS.xyz);
        #ifdef USE_VA
                float3 vertexMove = VertexAnimation(worldPos, input.positionOS, input.color);
                input.positionOS.xyz += vertexMove;
                worldPos = TransformObjectToWorld(input.positionOS.xyz);
        #endif

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = posInputs.positionCS;
                output.positionWS = worldPos;
                output.normalWS   = normalInputs.normalWS;
                output.tangentWS  = normalInputs.tangentWS;
                output.bitangentWS= normalInputs.bitangentWS;
                output.uv         = input.texcoord.xy;
                output.color      = input.color;
                output.shadowCoord= GetShadowCoord(posInputs);
                output.fogFactor  = ComputeFogFactor(output.positionCS.z);
                OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
                OUTPUT_SH(output.normalWS, output.vertexSH);
                output.dynamicUV = input.dynamicUV * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                return output;
            }

            half4 frag(Varyings input, half facing : VFACE) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                half4 albedo = SAMPLE_TEXTURE2D(_AlbedoTex, sampler_AlbedoTex, input.uv);
                clip(albedo.a - _CutOff);

                float3x3 t2w = float3x3(normalize(input.tangentWS), normalize(input.bitangentWS), normalize(input.normalWS));
                half3 tNormal = SampleNormal(TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap), input.uv, _NormalScale);
                half3 normalWS = TransformTangentToWorld(tNormal, t2w, facing);
                normalWS = NormalizeNormalPerPixel(normalWS);

                half3 viewDirWS = SafeNormalize(GetCameraPositionWS() - input.positionWS);

                half3 bakedGI;
            #ifdef LIGHTMAP_ON
                bakedGI = SampleBakedGI(input.lightmapUV, input.dynamicUV, normalWS);
            #else
                bakedGI = SampleBakedGI(0, 0, normalWS);
            #endif

                Light mainLight = GetMainLight(input.shadowCoord);
                mainLight.shadowAttenuation = lerp(1.0h, mainLight.shadowAttenuation, _ShadowIntensity);

                half3 transTex = SAMPLE_TEXTURE2D(_TransTex, sampler_TransTex, input.uv).rgb;
                half3 specTex = SAMPLE_TEXTURE2D(_SpecularTex, sampler_SpecularTex, input.uv).rgb;

                half3 lighting = bakedGI;
                lighting += EvaluateLight(mainLight, normalWS, viewDirWS, albedo.rgb, transTex, specTex);

        #ifdef _ADDITIONAL_LIGHTS
                uint lightCount = GetAdditionalLightsCount();
                for (uint li = 0u; li < lightCount; ++li)
                {
                    Light addLight = GetAdditionalLight(li, input.positionWS, normalWS);
                    lighting += EvaluateLight(addLight, normalWS, viewDirWS, albedo.rgb, transTex * 0.6h, specTex);
                }
        #endif

                half3 colorOut = lighting;
                colorOut = MixFog(colorOut, input.fogFactor);
                return half4(colorOut, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On ZTest LEqual
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5
            #pragma multi_compile_instancing

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 texcoord   : TEXCOORD0;
                float4 color      : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float3 worldPos = TransformObjectToWorld(input.positionOS.xyz);
        #ifdef USE_VA
                float3 vertexMove = VertexAnimation(worldPos, input.positionOS, input.color);
                input.positionOS.xyz += vertexMove;
        #endif

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = posInputs.positionCS;
                output.uv = input.texcoord.xy;
                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                half alpha = SAMPLE_TEXTURE2D(_AlbedoTex, sampler_AlbedoTex, input.uv).a;
                clip(alpha - _CutOff);
                return 0;
            }
            ENDHLSL
        }
    }
}
