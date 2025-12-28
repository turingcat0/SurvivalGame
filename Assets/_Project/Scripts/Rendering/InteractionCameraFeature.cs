using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class InteractionCameraFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
        public int rtSize = 512;
        public RenderTextureFormat rtFormat = RenderTextureFormat.RFloat;
        public string shaderTag = "Interaction";
        public string globalTextureName = "_InteractionRT";
    }



    class InteractionPass : ScriptableRenderPass
    {
        Settings s;
        private int globalTexId;

        public InteractionPass(Settings settings)
        {
            s =  new Settings();

            globalTexId = Shader.PropertyToID(settings.globalTextureName);
        }

        class PassData
        {
            public TextureHandle rt;
            public RendererListHandle rendererList;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var camData = frameData.Get<UniversalCameraData>();
            var renderData = frameData.Get<UniversalRenderingData>();
            var desc = new RenderTextureDescriptor(s.rtSize, s.rtSize, s.rtFormat)
            {
                msaaSamples = 1,
                depthBufferBits = 0,
                sRGB = false
            };
            var rtHandle = UniversalRenderer.CreateRenderGraphTexture(renderGraph, desc, "InteractionRT", true, FilterMode.Bilinear,
                TextureWrapMode.Repeat);
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
            using (var builder = renderGraph.AddRasterRenderPass<PassData>("InteractionRT", out var passData))
            {
                passData.rt = rtHandle;
                passData.rendererList = rendererList;
                builder.SetRenderAttachment(passData.rt, 0, AccessFlags.Write);
                builder.UseRendererList(passData.rendererList);
                builder.SetGlobalTextureAfterPass(passData.rt, globalTexId);
                builder.SetRenderFunc(static (PassData passData, RasterGraphContext context) =>
                {
                    context.cmd.ClearRenderTarget(RTClearFlags.All, Color.black, 1.0f, 0);
                    context.cmd.DrawRendererList(passData.rendererList);
                });
            }
        }
    }
    public Settings settings = new Settings();
    InteractionPass pass;

    public override void Create()
    {
        pass = new InteractionPass(settings)
        {
            renderPassEvent = settings.renderPassEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }
}
