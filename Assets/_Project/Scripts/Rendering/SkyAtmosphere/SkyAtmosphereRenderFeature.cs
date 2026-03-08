using System;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
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
        public ComputeShader computeShader;
        public Color groundAlbedo = new Color(0.3f, 0.3f, 0.3f, 1.0f);
        public float sunPower = 1.0f;

        // Atmosphere Size
        public float bottom = 6360000.0f;
        public float top = 6420000.0f;

        // Intensity
        public float rayleighScaleHeight = 8000.0f;
        public float mieScaleHeight = 1200.0f;
        public float ozoneCenter = 25000f;
        public float ozoneHalfWidth = 15000f;

        // Coefficient
        // All from the paper "A Scalable and Production Ready Sky and Atmosphere Rendering Technique"
        public Vector3 rayleighScattering = new Vector3(5.802e-6f, 13.558e-6f, 33.1e-6f);
        public Vector3 mieScattering = new Vector3(3.996e-6f, 3.996e-6f, 3.996e-6f);
        public Vector3 mieAbsorption = new Vector3(4.40e-6f, 4.40e-6f, 4.40e-6f);
        public Vector3 ozoneAbsorption = new Vector3(0.650e-6f, 1.881e-6f, 0.085e-6f);
        public float miePhaseFunctionG = 0.8f;
        public float sunAngularRadius = 0.00935f / 2.0f;
    }


    [SerializeField] SkyAtmosphereRenderFeatureSettings settings;
    SkyAtmosphereRenderFeaturePass pass;

    public override void Create()
    {
        pass = new SkyAtmosphereRenderFeaturePass(settings);

        // Configures where the render pass should be injected.
        pass.renderPassEvent = RenderPassEvent.BeforeRendering;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }

    protected override void Dispose(bool disposing)
    {
        pass?.Dispose();
    }

    class SkyAtmosphereRenderFeaturePass : ScriptableRenderPass
    {
        readonly SkyAtmosphereRenderFeatureSettings settings;

        private GraphicsBuffer skyAtmosphereParametersBuffer;

        private RTHandle transmittanceLut;
        private RTHandle multiScatteringLut;
        private RTHandle skyViewLut;

        private const int TransmittanceLutWidth = 256;
        private const int TransmittanceLutHeight = 64;
        private const int MultiScatteringLutWidth = 32;
        private const int MultiScatteringLutHeight = 32;
        private const int SkyViewLutWidth = 200;
        private const int SkyViewLutHeight = 100;


        public SkyAtmosphereRenderFeaturePass(SkyAtmosphereRenderFeatureSettings settings)
        {
            this.settings = settings;
        }

        private void EnsureResources()
        {
            int stride = Marshal.SizeOf<SkyAtmosphereBuffer>();
            skyAtmosphereParametersBuffer ??= new GraphicsBuffer(GraphicsBuffer.Target.Structured, 1, stride);

            transmittanceLut ??= RTHandles.Alloc(
                TransmittanceLutWidth, TransmittanceLutHeight,
                enableRandomWrite: true,
                filterMode: FilterMode.Bilinear,
                colorFormat: GraphicsFormat.R16G16B16A16_SFloat,
                // colorFormat: GraphicsFormat.R32G32B32A32_SFloat, //Debug only
                name: "_TransmittanceLut"
            );

            multiScatteringLut ??= RTHandles.Alloc(
                MultiScatteringLutWidth, MultiScatteringLutHeight,
                enableRandomWrite: true,
                filterMode: FilterMode.Bilinear,
                colorFormat: GraphicsFormat.R16G16B16A16_SFloat,
                // colorFormat: GraphicsFormat.R32G32B32A32_SFloat, //Debug only
                name: "_MultiScatteringLut"
            );

            skyViewLut ??= RTHandles.Alloc(
                SkyViewLutWidth, SkyViewLutHeight,
                enableRandomWrite: true,
                filterMode: FilterMode.Bilinear,
                colorFormat: GraphicsFormat.R16G16B16A16_SFloat,
                name: "_SkyViewLut"
            );
        }

        private SkyAtmosphereBuffer BuildSkyAtmosphereBuffer(Vector3 sunAngle, float cameraY)
        {
            return new SkyAtmosphereBuffer
            {
                atmospherePositionPacked = new Vector4(settings.bottom, settings.top, cameraY, settings.sunPower),
                sunParameterPacked = new Vector4(sunAngle.x, sunAngle.y, sunAngle.z, settings.sunAngularRadius),
                densityProfilePacked = new Vector4(1.0f / settings.rayleighScaleHeight, 1.0f / settings.mieScaleHeight,
                    settings.ozoneCenter, settings.ozoneHalfWidth),
                rayleighScattering = new Vector4(settings.rayleighScattering.x, settings.rayleighScattering.y,
                    settings.rayleighScattering.z, 1.0f),
                mieScatteringPacked = new Vector4(settings.mieScattering.x, settings.mieScattering.y,
                    settings.mieScattering.z, settings.miePhaseFunctionG),
                mieAbsorption = settings.mieAbsorption,
                ozoneAbsorption = settings.ozoneAbsorption,
                groundAlbedo = settings.groundAlbedo
            };
        }

        public void Dispose()
        {
            transmittanceLut?.Release();
            skyAtmosphereParametersBuffer?.Release();
            skyViewLut?.Release();
        }

        private class TransmittanceLutPassData
        {
            public ComputeShader shader;
            public int kernel;

            public TextureHandle transmittanceLut;
            public BufferHandle skyAtmosphereParameters;

            public int groupX, groupY;
        }

        private class MultiScatteringLutPassData
        {
            public ComputeShader shader;
            public int kernel;

            public TextureHandle transmittanceLut;
            public TextureHandle multiScatteringLut;
            public BufferHandle skyAtmosphereParameters;

            public int groupX, groupY;
        }

        private class SkyViewLutPassData
        {
            public ComputeShader shader;
            public int kernel;

            public TextureHandle transmittanceLut;
            public TextureHandle multiScatteringLut;
            public TextureHandle skyViewLut;
            public BufferHandle skyAtmosphereParameters;

            public int groupX, groupY;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            // 1. Update Atmosphere Buffer
            EnsureResources();
            var cameraData = frameData.Get<UniversalCameraData>();
            var camera = cameraData.camera;
            var lightData = frameData.Get<UniversalLightData>();

            Vector3 sunDirection = Vector3.up; // 默认给一个正午向上的方向

            if (lightData.mainLightIndex >= 0)
            {
                var mainLight = lightData.visibleLights[lightData.mainLightIndex];
                sunDirection = -mainLight.localToWorldMatrix.GetColumn(2).normalized;
            }

            var data = BuildSkyAtmosphereBuffer(sunDirection, camera.transform.position.y);
            skyAtmosphereParametersBuffer.SetData(new[] { data });

            // 2. Import Resources
            var parameterHandle = renderGraph.ImportBuffer(skyAtmosphereParametersBuffer);
            var transmittanceLutHandle = renderGraph.ImportTexture(transmittanceLut);
            var multiScatteringLutHandle = renderGraph.ImportTexture(multiScatteringLut);
            var skyViewLutHandle = renderGraph.ImportTexture(skyViewLut);

            // 3. Build TransmittanceLUTGen Pass
            using (var builder =
                   renderGraph.AddComputePass<TransmittanceLutPassData>("TransmittanceLutGen", out var passData))
            {
                // 3.1. Declare Used Resources
                builder.UseTexture(transmittanceLutHandle, AccessFlags.Write);
                builder.UseBuffer(parameterHandle, AccessFlags.Read);

                // 3.2. Prepare Pass Data
                passData.shader = settings.computeShader;
                passData.kernel = passData.shader.FindKernel("kComputeTransmittanceLut");

                passData.transmittanceLut = transmittanceLutHandle;
                passData.skyAtmosphereParameters = parameterHandle;

                passData.groupX = (TransmittanceLutWidth + 15) / 16;
                passData.groupY = (TransmittanceLutHeight + 15) / 16;

                // 3.3. Set Render Function
                builder.SetRenderFunc(static (TransmittanceLutPassData data, ComputeGraphContext ctx) =>
                {
                    var cmd = ctx.cmd;

                    cmd.SetComputeBufferParam(data.shader, data.kernel, "_SkyAtmosphereParametersBuffer",
                        data.skyAtmosphereParameters);
                    cmd.SetComputeTextureParam(data.shader, data.kernel, "_TransmittanceLutUAV",
                        data.transmittanceLut);
                    cmd.DispatchCompute(data.shader, data.kernel, data.groupX, data.groupY, 1);
                });
            }

            // 4. Build MultiScatteringLUTGen Pass
            using (var builder =
                   renderGraph.AddComputePass<MultiScatteringLutPassData>("MultiScatteringLUTGen", out var passData))
            {
                // 4.1. Declare Used Resources
                builder.UseTexture(transmittanceLutHandle, AccessFlags.Read);
                builder.UseTexture(multiScatteringLutHandle, AccessFlags.Write);
                builder.UseBuffer(parameterHandle, AccessFlags.Read);

                // 4.2 Prepare Pass Data
                passData.shader = settings.computeShader;
                passData.kernel = passData.shader.FindKernel("kComputeMultiScatteringLut");
                passData.transmittanceLut = transmittanceLutHandle;
                passData.skyAtmosphereParameters = parameterHandle;
                passData.multiScatteringLut = multiScatteringLutHandle;
                passData.groupX = (MultiScatteringLutWidth + 7) / 8;
                passData.groupY = (MultiScatteringLutHeight + 7) / 8;

                // 4.3. Set RenderFunc
                builder.SetRenderFunc(static (MultiScatteringLutPassData data, ComputeGraphContext ctx) =>
                {
                    var cmd = ctx.cmd;
                    cmd.SetComputeBufferParam(data.shader, data.kernel, "_SkyAtmosphereParametersBuffer",
                        data.skyAtmosphereParameters);
                    cmd.SetComputeTextureParam(data.shader, data.kernel, "_TransmittanceLut", data.transmittanceLut);
                    cmd.SetComputeTextureParam(data.shader, data.kernel, "_MultiScatteringLutUAV",
                        data.multiScatteringLut);
                    cmd.DispatchCompute(data.shader, data.kernel, data.groupX, data.groupY, 1);
                });
            }

            // 5. Build Sky-View Lut Pass
            using (var builder = renderGraph.AddComputePass<SkyViewLutPassData>("SkyViewLutGen", out var passData))
            {
                // 5.1. Declare Used Resources
                builder.UseTexture(transmittanceLutHandle, AccessFlags.Read);
                builder.UseTexture(multiScatteringLutHandle, AccessFlags.Read);
                builder.UseTexture(skyViewLutHandle, AccessFlags.Write);

                // 5.2 Prepare Pass Data
                passData.shader = settings.computeShader;
                passData.kernel = passData.shader.FindKernel("kComputeSkyViewLut");
                passData.skyAtmosphereParameters = parameterHandle;
                passData.groupX = (SkyViewLutWidth + 7) / 8;
                passData.groupY = (SkyViewLutHeight + 7) / 8;
                passData.transmittanceLut =  transmittanceLutHandle;
                passData.multiScatteringLut = multiScatteringLutHandle;
                passData.skyViewLut = skyViewLutHandle;

                // 5.3 Set RenderFunc
                builder.SetRenderFunc(static (SkyViewLutPassData data, ComputeGraphContext ctx) =>
                {
                    ctx.cmd.SetComputeBufferParam(data.shader, data.kernel, "_SkyAtmosphereParametersBuffer",
                        data.skyAtmosphereParameters);
                    ctx.cmd.SetComputeTextureParam(data.shader, data.kernel, "_TransmittanceLut", data.transmittanceLut);
                    ctx.cmd.SetComputeTextureParam(data.shader, data.kernel, "_MultiScatteringLut",
                        data.multiScatteringLut);
                    ctx.cmd.SetComputeTextureParam(data.shader, data.kernel, "_SkyViewLutUAV", data.skyViewLut);
                    ctx.cmd.DispatchCompute(data.shader, data.kernel, data.groupX, data.groupY, 1);
                });
            }


        }
    }


    [StructLayout(LayoutKind.Sequential)]
    struct SkyAtmosphereBuffer
    {
        public Vector4 atmospherePositionPacked; // bottom_radius, top_radius, camY, unused
        public Vector4 sunParameterPacked; // sunDirX, sunDirY, sunDirZ, sunAngularRadius (Y-up)

        public Vector4 densityProfilePacked; // rayleigh_expScale, mie_expScale, ozone_center, ozone_half_width

        public Vector4 rayleighScattering;
        public Vector4 mieScatteringPacked; // mieScatteringR, mieScatteringG, mieScatteringB, mie_phase_function_g
        public Vector4 mieAbsorption;
        public Vector4 ozoneAbsorption;
        public Vector4 groundAlbedo;
    }
}

