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
        public string shaderTag = "Interaction";
    }


    class InteractionPass : ScriptableRenderPass
    {
        Settings s;

        public InteractionPass(Settings settings)
        {
            s = settings;
        }

        class PassData
        {
            public RendererListHandle rendererList;
        }


        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var camData = frameData.Get<UniversalCameraData>();
            var renderData = frameData.Get<UniversalRenderingData>();
            var resData = frameData.Get<UniversalResourceData>();

            var rt = resData.activeColorTexture;

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
                passData.rendererList = rendererList;
                builder.SetRenderAttachment(rt, 0, AccessFlags.Write);

                builder.UseRendererList(passData.rendererList);
                builder.SetRenderFunc(static (PassData passData, RasterGraphContext context) =>
                {
                    context.cmd.ClearRenderTarget(RTClearFlags.Color, Color.white, 1.0f, 0);
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