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

            CBUFFER_START(UnityPerMaterial)
            float2 _Speed;
            CBUFFER_END


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
                float2 dirXZ = (l2 > 1e-12) ? (xz * rsqrt(l2)) : float2(0, 0) ;

                dirXZ *= float2(1, -1);
                float c = dot(dirXZ, _Speed);
                float atten = pow(1 - saturate(-c), 14.514f);
                float moving = saturate(step(1e-5, dot(_Speed, _Speed)) + 0.5f);

                //debug
                float2 forceDir = dirXZ * IN.pressure  * atten * moving;
                return float4(forceDir, saturate(depth01), saturate(IN.pressure));
            }
            ENDHLSL
        }
    }
}