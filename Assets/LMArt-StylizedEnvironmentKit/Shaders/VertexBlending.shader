//--------------------------------------------
// Stylized Environment Kit - URP rewrite
//--------------------------------------------

Shader "LMArtShader/VertexBlending"
{
    Properties
    {
        [Header(Red Channel)]
        [Space(7)][NoScaleOffset]_TopTex("Top Tex(Alpha used for Blending)", 2D) = "white" {}
        [Toggle(USE_TWUV)]_TopWorldUV("Use World UV", Float) = 0
        _TopUVScale("World UV Scale", Range(0,1)) = 0.5

        [NoScaleOffset]_TopBumpMap("Top Normal Map", 2D) = "bump" {}
        _TopBumpScale("Top Normal Scale", Range(0,1)) = 1.0

        [Space(24)][Header(Green Channel)]
        [Space(7)][NoScaleOffset]_MidTex("Middle Tex(Alpha used for Blending)", 2D) = "white" {}
        [Toggle(USE_MWUV)]_MidWorldUV("Use World UV", Float) = 0
        _MidUVScale("World UV Scale", Range(0,1)) = 0.5

        [NoScaleOffset]_MidBumpMap("Middle Normal Map", 2D) = "bump" {}
        _MidBumpScale("Middle Normal Scale", Range(0,1)) = 1.0

        [Space(24)][Header(Blue Channel)]
        [Space(7)][NoScaleOffset]_BtmTex("Bottom Tex(Alpha used for Blending)", 2D) = "white" {}
        [Toggle(USE_BWUV)]_BtmWorldUV("Use World UV", Float) = 0
        _BtmUVScale("World UV Scale", Range(0,1)) = 0.5

        [NoScaleOffset]_BtmBumpMap("Bottom Normal Map", 2D) = "bump" {}
        _BtmBumpScale("Buttom Normal Scale", Range(0,1)) = 1.0

        [Space(24)][Header(Others)]
        [Space(7)]_BlendFactor("BlendFactor", Range(0, 0.5)) = 0.2
        [Toggle(USE_RF)]_UseReflection("Use Reflection", Float) = 0
        _ReflectionColor("Reflection Light Color", Color) = (0.5,0.5,0.5,1)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }
        LOD 200

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

        TEXTURE2D(_TopTex);        SAMPLER(sampler_TopTex);
        TEXTURE2D(_MidTex);        SAMPLER(sampler_MidTex);
        TEXTURE2D(_BtmTex);        SAMPLER(sampler_BtmTex);
        TEXTURE2D(_TopBumpMap);    SAMPLER(sampler_TopBumpMap);
        TEXTURE2D(_MidBumpMap);    SAMPLER(sampler_MidBumpMap);
        TEXTURE2D(_BtmBumpMap);    SAMPLER(sampler_BtmBumpMap);

        CBUFFER_START(UnityPerMaterial)
            float4 _TopTex_ST;
            float4 _MidTex_ST;
            float4 _BtmTex_ST;
            half _TopBumpScale;
            half _MidBumpScale;
            half _BtmBumpScale;
            half _BlendFactor;
            half _TopUVScale;
            half _MidUVScale;
            half _BtmUVScale;
            half _TopWorldUV;
            half _MidWorldUV;
            half _BtmWorldUV;
            half _UseReflection;
            half3 _ReflectionColor;
        CBUFFER_END

        inline half2 MaskBlending(float4 color, half4 topcol, half4 midcol, half4 btmcol)
        {
            half maskR = lerp(0, topcol.a, color.r);
            half maskG = lerp(0, midcol.a, color.g);
            half maskB = lerp(0, btmcol.a, max(0, 1 - color.r - color.g));

            half maskRGB = smoothstep(0.9, 1, color.r) + smoothstep(0, (0.5 - _BlendFactor), max(0, maskR - maskB - maskG));
            maskRGB = min(maskRGB, 1.0);

            half maskGB = max(0, smoothstep(0, 0.1, color.g) - smoothstep(0, 0.1, color.b)) + smoothstep(0, (0.5 - _BlendFactor), max(0, maskG - maskB - maskR));
            maskGB = min(maskGB, 1.0);

            return half2(maskGB, maskRGB);
        }

        inline half3 TransformTangentToWorld(half3 n, float3x3 t2w)
        {
            return normalize(mul(n, t2w));
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

        inline half3 ApplyAdditionalLights(half3 normalWS, float3 positionWS, half3 albedo)
        {
            half3 lighting = 0;
        #ifdef _ADDITIONAL_LIGHTS
            uint lightCount = GetAdditionalLightsCount();
            for (uint li = 0u; li < lightCount; ++li)
            {
                Light light = GetAdditionalLight(li, positionWS, normalWS);
                half NdotL = saturate(dot(normalWS, light.direction));
                lighting += albedo * (NdotL * light.color * light.distanceAttenuation * light.shadowAttenuation);
            }
        #endif
            return lighting;
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
            #pragma shader_feature _ USE_RF
            #pragma multi_compile_instancing

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
                float2 dynamicUV  : TEXCOORD2;
                float4 color      : COLOR;
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

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;
                output.normalWS   = normalInputs.normalWS;
                output.tangentWS  = normalInputs.tangentWS;
                output.bitangentWS= normalInputs.bitangentWS;
                output.uv         = input.uv;
				output.color      = input.color;
				output.shadowCoord= GetShadowCoord(posInputs);
				output.fogFactor  = ComputeFogFactor(output.positionCS.z);
				OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
				OUTPUT_SH(output.normalWS, output.vertexSH);
				output.dynamicUV = input.dynamicUV * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
				return output;
			}

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float3x3 t2w = float3x3(normalize(input.tangentWS), normalize(input.bitangentWS), normalize(input.normalWS));
                half2 worldUV = input.positionWS.xz * -1.0h;

                half2 topUV = lerp(TRANSFORM_TEX(input.uv, _TopTex), worldUV * _TopUVScale, _TopWorldUV);
                half2 midUV = lerp(TRANSFORM_TEX(input.uv, _MidTex), worldUV * _MidUVScale, _MidWorldUV);
                half2 btmUV = lerp(TRANSFORM_TEX(input.uv, _BtmTex), worldUV * _BtmUVScale, _BtmWorldUV);

                half4 topCol = SAMPLE_TEXTURE2D(_TopTex, sampler_TopTex, topUV);
                half4 midCol = SAMPLE_TEXTURE2D(_MidTex, sampler_MidTex, midUV);
                half4 btmCol = SAMPLE_TEXTURE2D(_BtmTex, sampler_BtmTex, btmUV);

                half2 maskBD = MaskBlending(input.color, topCol, midCol, btmCol);
                half4 col = lerp(lerp(btmCol, midCol, maskBD.x), topCol, maskBD.y);

                half3 topNormal = SampleNormal(TEXTURE2D_ARGS(_TopBumpMap, sampler_TopBumpMap), topUV, _TopBumpScale);
                half3 midNormal = SampleNormal(TEXTURE2D_ARGS(_MidBumpMap, sampler_MidBumpMap), midUV, _MidBumpScale);
                half3 btmNormal = SampleNormal(TEXTURE2D_ARGS(_BtmBumpMap, sampler_BtmBumpMap), btmUV, _BtmBumpScale);

                half3 tNormal = lerp(lerp(btmNormal, midNormal, maskBD.x), topNormal, maskBD.y);
                half3 normalWS = TransformTangentToWorld(tNormal, t2w);
                normalWS = NormalizeNormalPerPixel(normalWS);

                half3 bakedGI;
            #ifdef LIGHTMAP_ON
                bakedGI = SampleBakedGI(input.lightmapUV, input.dynamicUV, normalWS);
            #else
                bakedGI = SampleBakedGI(0, 0, normalWS);
            #endif

                Light mainLight = GetMainLight(input.shadowCoord);
                half NdotL = saturate(dot(normalWS, mainLight.direction));
                half3 mainLighting = NdotL * mainLight.color * mainLight.shadowAttenuation;

                half3 reflectLight = 0;
            #ifdef USE_RF
                reflectLight = _ReflectionColor * saturate(dot(normalWS, -mainLight.direction));
            #endif

                half3 lighting = bakedGI + mainLighting;
                lighting += ApplyAdditionalLights(normalWS, input.positionWS, col.rgb);

                half3 finalColor = col.rgb * lighting + reflectLight;

                half fogFactor = input.fogFactor;
                finalColor = MixFog(finalColor, fogFactor);
                return half4(finalColor, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On ZTest LEqual

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5
            #pragma multi_compile_instancing

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

			Varyings vert(Attributes input)
			{
				Varyings output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
				output.positionCS = posInputs.positionCS;
				return output;
			}

            float4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                return 0;
            }
            ENDHLSL
        }
    }
    Fallback Off
}
