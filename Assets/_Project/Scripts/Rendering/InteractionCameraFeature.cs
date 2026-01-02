using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class InteractionCameraFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
        public string shaderTag = "Interaction";
        public string globalTextureName = "_InteractionRT";
        public int rtSize = 512;
        public float recoverSpeed = 1.5f;
        public float resistance = 0.5f;
    }

    public Shader resolveShader;


    class InteractionPass : ScriptableRenderPass
    {
        Settings s;
        RTHandle rtA;
        RTHandle rtB;
        bool aOrB = true;

        Material resolveMaterial;
        Vector4 lastCenterWS;
        bool hasHistory;

        static readonly int PrevTextureID = Shader.PropertyToID("_PrevTexture");
        static readonly int ImpulseTextureID = Shader.PropertyToID("_ImpulseTexture");
        static readonly int DeltaTimeID = Shader.PropertyToID("_DeltaTime");
        static readonly int RecoverySpeedID = Shader.PropertyToID("_RecoverySpeed");
        static readonly int ReprojectOffsetID = Shader.PropertyToID("_ReprojectOffset");
        static readonly int ResistanceID = Shader.PropertyToID("_Resistance");

        static readonly int CenterID = Shader.PropertyToID("_InteractionCenterWS");
        static readonly int RadiusID = Shader.PropertyToID("_InteractionRadius");


        public InteractionPass(Settings settings, Shader decayShader)
        {
            s = settings;
            if (decayShader)
            {
                resolveMaterial = CoreUtils.CreateEngineMaterial(decayShader);
            }
        }

        void EnsureRT()
        {
            if (rtA == null || rtA.rt == null || rtA.rt.width != s.rtSize || rtA.rt.height != s.rtSize)
            {
                rtA?.Release();

                rtA = RTHandles.Alloc(
                    s.rtSize, // width
                    s.rtSize, // height
                    1, // slices
                    DepthBits.None, // depth
                    GraphicsFormat.R16G16B16A16_SNorm, // ARGBHalf
                    FilterMode.Bilinear,
                    TextureWrapMode.Clamp,
                    TextureDimension.Tex2D,
                    false, // useMipMap
                    false, // autoGenerateMips
                    false, // isShadowMap
                    false, // enableRandomWrite
                    1, // anisoLevel
                    0.0f, // mipMapBias
                    MSAASamples.None,
                    false, // bindTextureMS
                    false, // useDynamicScale
                    false, // useDynamicScaleExplicit
                    RenderTextureMemoryless.None,
                    VRTextureUsage.None,
                    "_InteractionRT_InternalA"
                );
                var active = RenderTexture.active;
                RenderTexture.active = rtA.rt; GL.Clear(true, true, Color.clear);
                RenderTexture.active = active;
                hasHistory = false;
            }

            if (rtB == null || rtB.rt == null || rtB.rt.width != s.rtSize || rtB.rt.height != s.rtSize)
            {
                rtB?.Release();

                rtB = RTHandles.Alloc(
                    s.rtSize, // width
                    s.rtSize, // height
                    1, // slices
                    DepthBits.None, // depth
                    GraphicsFormat.R16G16B16A16_SNorm, // ARGBHalf
                    FilterMode.Bilinear,
                    TextureWrapMode.Clamp,
                    TextureDimension.Tex2D,
                    false, // useMipMap
                    false, // autoGenerateMips
                    false, // isShadowMap
                    false, // enableRandomWrite
                    1, // anisoLevel
                    0.0f, // mipMapBias
                    MSAASamples.None,
                    false, // bindTextureMS
                    false, // useDynamicScale
                    false, // useDynamicScaleExplicit
                    RenderTextureMemoryless.None,
                    VRTextureUsage.None,
                    "_InteractionRT_InternalB"
                );
                var active = RenderTexture.active;
                RenderTexture.active = rtB.rt; GL.Clear(true, true, Color.clear);
                RenderTexture.active = active;
            }
        }

        public void Dispose()
        {
            rtA?.Release();
            rtA = null;
            rtB?.Release();
            rtB = null;
            CoreUtils.Destroy(resolveMaterial);
            resolveMaterial = null;
        }

        class StampData
        {
            public RendererListHandle RendererList;
            public TextureHandle ImpulseTexture;
        }

        class DecayData
        {
            public TextureHandle Prev;
            public TextureHandle ImpulseTexture;
            public TextureHandle curr;
        }


        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            EnsureRT();
            if (resolveMaterial == null)
            {
                return;
            }

            var camData = frameData.Get<UniversalCameraData>();
            var renderData = frameData.Get<UniversalRenderingData>();

            // Pass 1, stamp -> impulse
            var shaderTag = new ShaderTagId(s.shaderTag);

            var sorting = new SortingSettings(camData.camera);
            var drawing = new DrawingSettings(shaderTag, sorting)
            {
                perObjectData = renderData.perObjectData,
                enableInstancing = true,
                enableDynamicBatching = renderData.supportsDynamicBatching
            };
            var filtering = new FilteringSettings(RenderQueueRange.all);
            var renderListParam = new RendererListParams(renderData.cullResults, drawing, filtering);
            var rendererList = renderGraph.CreateRendererList(renderListParam);

            var impulseTextureDesc = new TextureDesc(s.rtSize, s.rtSize)
            {
                colorFormat = GraphicsFormat.R16G16B16A16_SNorm,
                depthBufferBits = DepthBits.None,
                msaaSamples = MSAASamples.None,
                filterMode = FilterMode.Bilinear,
                wrapMode = TextureWrapMode.Clamp,
                name = "InteractionImpulse"
            };

            var impulseTexture = renderGraph.CreateTexture(impulseTextureDesc);

            using (var builder = renderGraph.AddRasterRenderPass<StampData>("InteractionRT", out var passData))
            {
                passData.RendererList = rendererList;
                passData.ImpulseTexture = impulseTexture;

                builder.SetRenderAttachment(passData.ImpulseTexture, 0, AccessFlags.Write);
                builder.UseRendererList(passData.RendererList);

                builder.SetRenderFunc(static (StampData stampData, RasterGraphContext context) =>
                {
                    context.cmd.ClearRenderTarget(RTClearFlags.Color, Color.clear, 1.0f, 0);
                    context.cmd.DrawRendererList(stampData.RendererList);
                });
            }


            // Pass 2 , prev + impulse -> curr
            var prevRT = aOrB ? rtA : rtB;
            var currRT = aOrB ? rtB : rtA;
            aOrB = !aOrB;

            var prev = renderGraph.ImportTexture(prevRT);
            var curr = renderGraph.ImportTexture(currRT);

            var curCenterWS = Shader.GetGlobalVector(CenterID);
            float radius = Shader.GetGlobalFloat(RadiusID);
            var offset = Vector2.zero;

            if (hasHistory)
            {
                float denom = Mathf.Max(1e-6f, 2.0f * radius);
                offset = new Vector2(curCenterWS.x - lastCenterWS.x, curCenterWS.z - lastCenterWS.z) / denom;
            }

            lastCenterWS = curCenterWS;
            hasHistory = true;

            float dt = Application.isPlaying ? Time.deltaTime : Time.unscaledDeltaTime;
            dt = Mathf.Clamp(dt, 0.0f, 0.1f);

            using (var builder = renderGraph.AddRasterRenderPass<DecayData>("InteractRT_Decay", out var passData))
            {
                passData.Prev = prev;
                passData.ImpulseTexture = impulseTexture;
                passData.curr = curr;

                builder.UseTexture(passData.Prev, AccessFlags.Read);
                builder.UseTexture(passData.ImpulseTexture, AccessFlags.Read);
                builder.SetRenderAttachment(passData.curr, 0, AccessFlags.Write);

                builder.SetRenderFunc((DecayData data, RasterGraphContext ctx) =>
                {
                    resolveMaterial.SetTexture(PrevTextureID, data.Prev);
                    resolveMaterial.SetTexture(ImpulseTextureID, data.ImpulseTexture);
                    resolveMaterial.SetFloat(DeltaTimeID, dt);
                    resolveMaterial.SetFloat(RecoverySpeedID, s.recoverSpeed);
                    resolveMaterial.SetVector(ReprojectOffsetID, offset);
                    resolveMaterial.SetFloat(ResistanceID,  s.resistance);
                    CoreUtils.DrawFullScreen(ctx.cmd, resolveMaterial, shaderPassId: 0);
                });
            }

            SharedInteractionRT = currRT.rt;
        }
    }

    public Settings settings = new Settings();

    InteractionPass pass;
    public static RenderTexture SharedInteractionRT;
    public static int SharedInteractionTexId;


    public override void Create()
    {
        SharedInteractionTexId = Shader.PropertyToID(settings.globalTextureName);
        pass = new InteractionPass(settings, resolveShader)
        {
            renderPassEvent = settings.renderPassEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }

    protected override void Dispose(bool disposing)
    {
        pass?.Dispose();
    }
}