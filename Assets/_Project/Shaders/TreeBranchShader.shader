Shader "TuringCat/Branch"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map", 2D) = "black"
        _NormalMap("Normal Map", 2D) = "black"
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            HLSLPROGRAM
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
                OUT.tbn0 = normalInputs.normalWS;
                OUT.tbn1 = normalInputs.tangentWS;
                OUT.tbn2 = normalInputs.bitangentWS;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half4 nTex = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.normalUV);
                half3 tNormal = UnpackNormal(nTex);
                half3 wNormal = TransformTangentToWorld(tNormal, half3x3(IN.tbn0, IN.tbn1, IN.tbn2), true);

                // Lighting
                TransformWorldToShadowCoord()
                Light mainLight = GetMainLight();
                half3 l = normalize(mainLight.direction);
                half3 ndl = saturate(dot(wNormal, l));


                return color;
            }
            ENDHLSL
        }
    }
}