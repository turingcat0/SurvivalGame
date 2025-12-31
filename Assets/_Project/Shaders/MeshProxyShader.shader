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
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
            };


            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(posWS);
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float ndcZ = IN.positionHCS.z / IN.positionHCS.w;
                float depth01 = (ndcZ - UNITY_NEAR_CLIP_VALUE) / (UNITY_RAW_FAR_CLIP_VALUE - UNITY_NEAR_CLIP_VALUE);
                return float4(0.0f, 0.0f, saturate(depth01), 1.0f);
            }
            ENDHLSL
        }
    }
}