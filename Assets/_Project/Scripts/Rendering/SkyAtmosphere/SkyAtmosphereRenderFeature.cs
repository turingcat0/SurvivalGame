using System;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Serialization;

public class SkyAtmosphereRenderFeature : ScriptableRendererFeature
{
    // Use this class to pass around settings from the feature to the pass
    [Serializable]
    public class SkyAtmosphereRenderFeatureSettings
    {
        public DirectionalLight sun;

        // Atmosphere Size
        public float bottom = 6360000.0f;
        public float top = 6420000.0f;

        // Intensity
        public float rayleighScaleHeight = 8000.0f;
        public float mieScaleHeight = 1200.0f;
        public float ozoneCenter = 25000f;
        public float ozoneRadius = 15000f;

        // Coefficient
        // All from the paper "A Scalable and Production Ready Sky and Atmosphere Rendering Technique"
        public Vector3 rayleighScattering = new Vector3(5.802e-6f, 13.558e-6f, 33.1e-6f);
        public Vector3 mieScattering = new Vector3(3.996e-6f, 3.996e-6f, 3.996e-6f);
        public Vector3 mieAbsorption = new Vector3(4.40e-6f, 4.40e-6f, 4.40e-6f);
        public Vector3 ozoneAbsorption = new Vector3(0.650e-6f, 1.881e-6f, 0.085e-6f);
    }

    class IntensityProfileLayer
    {
        public float width;
        public float expTerm;
        public float expScale;
        public float linearTerm;
        public float constantTerm;

        public IntensityProfileLayer(float width, float expTerm, float expScale, float linearTerm, float constantTerm)
        {
            this.width = width;
            this.expTerm = expTerm;
            this.expScale = expScale;
            this.linearTerm = linearTerm;
            this.constantTerm = constantTerm;
        }
    }


    [SerializeField] SkyAtmosphereRenderFeatureSettings settings;
    SkyAtmosphereRenderFeaturePass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new SkyAtmosphereRenderFeaturePass(settings);

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }


    class SkyAtmosphereRenderFeaturePass : ScriptableRenderPass
    {
        readonly SkyAtmosphereRenderFeatureSettings settings;

        public SkyAtmosphereRenderFeaturePass(SkyAtmosphereRenderFeatureSettings settings)
        {
            this.settings = settings;
        }

        // This class stores the data needed by the RenderGraph pass.
        // It is passed as a parameter to the delegate function that executes the RenderGraph pass.
        private class PassData
        {
        }

        // This static method is passed as the RenderFunc delegate to the RenderGraph render pass.
        // It is used to execute draw commands.
        static void ExecutePass(PassData data, RasterGraphContext context)
        {
        }

        // RecordRenderGraph is where the RenderGraph handle can be accessed, through which render passes can be added to the graph.
        // FrameData is a context container through which URP resources can be accessed and managed.
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            const string passName = "Render Custom Pass";

            // This adds a raster render pass to the graph, specifying the name and the data type that will be passed to the ExecutePass function.
            using (var builder = renderGraph.AddRasterRenderPass<PassData>(passName, out var passData))
            {
                // Use this scope to set the required inputs and outputs of the pass and to
                // setup the passData with the required properties needed at pass execution time.

                // Make use of frameData to access resources and camera data through the dedicated containers.
                // Eg:
                // UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();
                UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();

                // Setup pass inputs and outputs through the builder interface.
                // Eg:
                // builder.UseTexture(sourceTexture);
                // TextureHandle destination = UniversalRenderer.CreateRenderGraphTexture(renderGraph, cameraData.cameraTargetDescriptor, "Destination Texture", false);

                // This sets the render target of the pass to the active color texture. Change it to your own render target as needed.
                builder.SetRenderAttachment(resourceData.activeColorTexture, 0);

                // Assigns the ExecutePass function to the render pass delegate. This will be called by the render graph when executing the pass.
                builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));
            }
        }
    }
}