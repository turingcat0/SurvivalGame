Shader "TuringCat/VFX/MeshProxyShader"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

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
                float heightWS : TEXCOORD0;
            };


            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.heightWS = posWS.y;
                OUT.positionHCS = TransformObjectToHClip(posWS);
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                return float4(IN.heightWS, .0f, .0f, 1.0f);
            }
            ENDHLSL
        }
    }
}
