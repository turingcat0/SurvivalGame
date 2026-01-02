Shader "TuringCat/VFX/ResolveShader"
{

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            ZWrite Off
            ZTest Always
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_PrevTexture);
            SAMPLER(sampler_PrevTexture);
            TEXTURE2D(_ImpulseTexture);
            SAMPLER(sampler_ImpulseTexture);

            CBUFFER_START(DECAY_SHADER_GLOBAL)
                float _DeltaTime;
                float _RecoverySpeed;
                float2 _ReprojectOffset;
                float _Resistance;

            CBUFFER_END


            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(uint id: SV_VertexID)
            {
                Varyings OUT;
                OUT.positionHCS = GetFullScreenTriangleVertexPosition(id);
                OUT.uv = GetFullScreenTriangleTexCoord(id);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 uvPrev = IN.uv + _ReprojectOffset;

                float2 in2 = step(0.0, uvPrev) * step(uvPrev, 1.0);
                float in01 = in2.x * in2.y;

                float4 prev = SAMPLE_TEXTURE2D_LOD(_PrevTexture, sampler_PrevTexture, uvPrev, 0);
                prev = lerp(0, prev, in01);

                float4 impulse = SAMPLE_TEXTURE2D_LOD(_ImpulseTexture, sampler_ImpulseTexture, IN.uv, 0);

                float k = max(0, _RecoverySpeed);
                float decay = exp(-k * _DeltaTime);
                // debug
                // float4 decayedPrev = prev * decay;
                float4 decayedPrev = prev;

                float resistance = saturate(dot(decayedPrev.xy, decayedPrev.xy) * 0.5);
                resistance = pow(1 - resistance, _Resistance);
                return lerp(decayedPrev, impulse, resistance);
            }
            ENDHLSL
        }
    }
}