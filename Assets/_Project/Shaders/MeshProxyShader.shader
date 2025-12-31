Shader "TuringCat/VFX/MeshProxyShader"
{
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "Interaction"
            Tags
            {
                "LightMode" = "Interaction"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float pressure : TEXCOORD1;
            };


            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS, true);
                OUT.pressure = abs(OUT.normalWS.y);
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float ndcZ = IN.positionHCS.z / IN.positionHCS.w;
                // REVERSED_Z, Platform, etc
                float depth01 = (ndcZ - UNITY_NEAR_CLIP_VALUE) / (UNITY_RAW_FAR_CLIP_VALUE - UNITY_NEAR_CLIP_VALUE);
                float2 xz = IN.normalWS.xz;
                float l2 = dot(xz, xz);
                float2 dirXZ = (l2 > 1e-12) ? (xz * rsqrt(l2)) : float2(0, 0);
                float2 forceDir = dirXZ * IN.pressure * float2(1, -1);
                return float4((forceDir + 1.0f) / 2, saturate(depth01), 1.0f);
            }
            ENDHLSL
        }
    }
}