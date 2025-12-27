Shader "TuringCat/Nature/Grass"
{
    Properties
    {
        [Header(Base)]
        [Space(7)]
        [MainTexture] _BaseMap("Base Map", 2D) = "black" {}
        _NormalMap("Normal Map", 2D) = "bump" {}
        _CutOff("CutOff", Range(0,1)) = 0.5

        [Space(16)]
        [Header(Translucency)]
        [Space(7)]
        [Toggle(USE_TRANS)] _EnableTrans("Enable Translucency", Float) = 1.0
        [NoScaleOffset] _TransMap("Translucency Map", 2D) = "black" {}
        [HDR]_TransColor("Translucency Color", Color) = (1, 1, 1, 1)
        _TransThreshold("Translucency Threshold", Range(0, 1)) = 0.0
        _TransStrength("Translucency Strength", Range(0, 1)) = 1.0
        _TransSharpness("Translucency Sharpness", Range(0.01, 16)) = 4.0

        [Space(16)]
        [Header(Specular)]
        [Space(7)]
        [Toggle(USE_SPECULAR)] _EnableSpecular("Enable Specular", Float) = 1.0
        [NoScaleOffset] _SpecMap("Specular Map", 2D) = "black" {}
        _SpecStrength("Specular Strength", Range(0, 3)) = 1.0
        _SpecShininess("Specular Shininess", Range(1, 96)) = 12

        [Space(16)][Header(Aninmation)]
        [Space(7)]
        [Toggle(USE_AN)]_UseAnimation("Use Animation", Float) = 1.0
        _AnimationScale("Animation Scale", Range(0,1)) = 1.0

        [Space(16)]
        [Header(Billboard)]
        [Space(7)]
        [Toggle(USE_BILLBOARD)] _IsBillBoard("Use Billboard", Float) = 0.0

    }


    SubShader
    {
        Tags
        {
            "RenderType" = "TransparencyCutout" "RenderPipeline" = "UniversalPipeline" "Queue"="AlphaTest"
        }

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            Cull Off

            HLSLPROGRAM
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fog
            #pragma multi_compile_instancing


            #pragma shader_feature USE_TRANS
            #pragma shader_feature USE_SPECULAR
            #pragma shader_feature USE_BILLBOARD
            #pragma shader_feature USE_AN


            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Common.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                #ifdef USE_AN
                half4 color : COLOR;
                #endif

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
                half fogFactor : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            TEXTURE2D(_TransMap);
            SAMPLER(sampler_TransMap);
            TEXTURE2D(_SpecMap);
            SAMPLER(sampler_SpecMap);

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
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                // Billboard
                #ifdef USE_BILLBOARD
                float3 centerWS = TransformObjectToWorld(float3(0, 0, 0));
                float3 camWS = GetCameraPositionWS();
                float3 toCam = camWS - centerWS;
                toCam.y = 0;
                toCam = normalize(toCam + 1e-05);
                float3 up = float3(0, 1, 0);
                float3 right = normalize(cross(toCam, up));

                float4x4 o2w = GetObjectToWorldMatrix();

                float3 col0 = float3(o2w._m00, o2w._m10, o2w._m20);
                float3 col1 = float3(o2w._m01, o2w._m11, o2w._m21);
                float3 col2 = float3(o2w._m02, o2w._m12, o2w._m22);

                OUT.positionWS = centerWS + IN.positionOS.z * right * length(col2) + IN.positionOS.y * up * length(col1);
                #else
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                #endif
                #ifdef USE_AN
                float3 anim = vertexAnimation(OUT.positionWS, IN.positionOS, IN.color, _AnimationScale);
                OUT.positionWS += anim;
                #endif

                OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
                OUT.fogFactor = ComputeFogFactor(OUT.positionHCS.z);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.normalUV = TRANSFORM_TEX(IN.uv, _NormalMap);

                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.tbn0 = normalInputs.tangentWS;
                OUT.tbn1 = normalInputs.bitangentWS;
                OUT.tbn2 = normalInputs.normalWS;

                return OUT;
            }

            half4 frag(Varyings IN, half facing : VFACE) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                clip(color.a - _CutOff);

                half4 nTex = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.normalUV);
                half3 tNormal = UnpackNormal(nTex);
                half3 wNormal = sign(facing) * TransformTangentToWorld(
                    tNormal, half3x3(IN.tbn0, IN.tbn1, IN.tbn2), true);
                // Lighting
                // Main Light
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                half3 l = normalize(mainLight.direction);
                half4 finalCol = 0;

                // diffuse
                half ndl = saturate(dot(wNormal, l));
                finalCol.xyz += color.xyz * ndl * mainLight.color * mainLight.shadowAttenuation;


                //Additional Light
                int addCount = GetAdditionalLightsCount();
                for (int i = 0; i < addCount; ++i)
                {
                    Light addLight = GetAdditionalLight(i, IN.positionWS);
                    half3 addLightDir = normalize(addLight.direction);
                    half3 addNdL = saturate(dot(addLightDir, wNormal));

                    finalCol.xyz += color.xyz * addNdL * addLight.color * addLight.distanceAttenuation * addLight.
                        shadowAttenuation;
                }

                // Ambient Light
                half3 sh = SampleSH(wNormal);
                finalCol.xyz += sh * color.xyz;

                // Translucency
                #ifdef USE_TRANS
                half nndl = saturate(dot(-wNormal, l));

                half4 transColor = SAMPLE_TEXTURE2D(_TransMap, sampler_TransMap, IN.uv);

                half3 trans1 = _TransColor.xyz * transColor.xyz * mainLight.color * mainLight.shadowAttenuation * smoothstep(
                    _TransThreshold, 1, nndl);
                finalCol.xyz += trans1;
                half3 trans2 = _TransColor.xyz * _TransStrength * mainLight.color * transColor.xyz * pow(nndl, _TransSharpness) *
                    mainLight.shadowAttenuation;
                finalCol.xyz += trans2;
                #endif

                // Specular
                #ifdef USE_SPECULAR
                half4 specColor = SAMPLE_TEXTURE2D(_SpecMap, sampler_SpecMap, IN.uv);

                half3 ref = reflect(-l, wNormal);
                half3 viewDir = normalize(GetWorldSpaceViewDir(IN.positionWS));
                half rdv = saturate(dot(ref, viewDir));

                half3 spec = pow(rdv, _SpecShininess) * specColor.rgb * mainLight.color.rgb * mainLight.
                    shadowAttenuation * specColor.a;
                finalCol.xyz += spec;
                #endif
                finalCol.xyz = MixFog(finalCol.xyz, IN.fogFactor);
                finalCol.a = 1;
                return finalCol;
            }
            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }
            ZWrite On
            ZTest LEqual
            Cull Off


            HLSLPROGRAM
            #pragma vertex shadowVert
            #pragma fragment shadowFrag
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma multi_compile_instancing
            #pragma shader_feature USE_BILLBOARD
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            float3 _LightDirection;
            float3 _LightPosition;

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float _CutOff;
            CBUFFER_END

            struct Attributes
            {
                float4 posOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varings
            {
                float4 clipPos : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varings shadowVert(Attributes attr)
            {
                Varings OUT;
                UNITY_SETUP_INSTANCE_ID(attr);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                OUT.uv = TRANSFORM_TEX(attr.uv, _BaseMap);
                // Billboard
                #ifdef USE_BILLBOARD
                float3 centerWS = TransformObjectToWorld(float3(0, 0, 0));
                float3 camWS = GetCameraPositionWS();
                float3 toCam = camWS - centerWS;
                toCam.y = 0;
                toCam = normalize(toCam + 1e-05);
                float3 up = float3(0, 1, 0);
                float3 right = normalize(cross(toCam, up));

                float4x4 o2w = GetObjectToWorldMatrix();

                float3 col0 = float3(o2w._m00, o2w._m10, o2w._m20);
                float3 col1 = float3(o2w._m01, o2w._m11, o2w._m21);
                float3 col2 = float3(o2w._m02, o2w._m12, o2w._m22);

                 float3 worldPos = centerWS + attr.posOS.z * right * col2 + attr.posOS.y * up * col1;
                #else
                float3 worldPos = TransformObjectToWorld(attr.posOS.xyz);
                #endif


                float3 worldNormal = TransformObjectToWorldNormal(attr.normalOS);
                float3 biasedPos = ApplyShadowBias(worldPos, worldNormal, _LightDirection);
                OUT.clipPos = TransformWorldToHClip(biasedPos);

                #if UNITY_REVERSED_Z
                OUT.clipPos.z = min(OUT.clipPos.z, OUT.clipPos.w * UNITY_NEAR_CLIP_VALUE);
                #else
                OUT.clipPos.z = max(OUT.clipPos.z, OUT.clipPos.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                return OUT;
            }

            half4 shadowFrag(Varings varings) : SV_TARGET
            {
                half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, varings.uv).a;
                clip(alpha - _CutOff);
                return 0;
            }
            ENDHLSL
        }
    }
}