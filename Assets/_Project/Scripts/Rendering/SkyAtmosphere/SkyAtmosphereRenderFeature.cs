using System;
using System.Runtime.InteropServices;
using TuringCat.Rendering.SkyAtomshpere;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

public class SkyAtmosphereRenderFeature : ScriptableRendererFeature
{
    [SerializeField] ComputeShader computeShader;

    SkyAtmosphereRenderFeaturePass pass;

    public override void Create()
    {
        pass = new SkyAtmosphereRenderFeaturePass(computeShader);

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
        readonly ComputeShader computeShader;

        private GraphicsBuffer skyAtmosphereParametersBuffer;

        private RTHandle transmittanceLut;
        private RTHandle multiScatteringLut;
        private RTHandle skyViewLut;
        private RTHandle aerialPerspectiveLut;

        private const int TransmittanceLutWidth = 256;
        private const int TransmittanceLutHeight = 64;
        private const int MultiScatteringLutWidth = 32;
        private const int MultiScatteringLutHeight = 32;
        private const int SkyViewLutWidth = 1024;
        private const int SkyViewLutHeight = 1024;
        private const int AerialPerspectiveLutSize = 32;

        public SkyAtmosphereRenderFeaturePass(ComputeShader computeShader)
        {
            this.computeShader = computeShader;
        }

        private void EnsureResources()
        {
            int stride = Marshal.SizeOf<SkyAtmosphereBuffer>();
            skyAtmosphereParametersBuffer ??= new GraphicsBuffer(GraphicsBuffer.Target.Structured, 1, stride);

            transmittanceLut ??= RTHandles.Alloc(
                TransmittanceLutWidth, TransmittanceLutHeight,
                enableRandomWrite: true,
                filterMode: FilterMode.Bilinear,
                wrapMode: TextureWrapMode.Clamp,
                colorFormat: GraphicsFormat.R16G16B16A16_SFloat,
                // colorFormat: GraphicsFormat.R32G32B32A32_SFloat, //Debug only
                name: "_TransmittanceLut"
            );

            multiScatteringLut ??= RTHandles.Alloc(
                MultiScatteringLutWidth, MultiScatteringLutHeight,
                enableRandomWrite: true,
                filterMode: FilterMode.Bilinear,
                wrapMode: TextureWrapMode.Clamp,
                colorFormat: GraphicsFormat.R16G16B16A16_SFloat,
                // colorFormat: GraphicsFormat.R32G32B32A32_SFloat, //Debug only
                name: "_MultiScatteringLut"
            );


            skyViewLut ??= RTHandles.Alloc(
                SkyViewLutWidth, SkyViewLutHeight,
                enableRandomWrite: true,
                filterMode: FilterMode.Bilinear,
                wrapMode: TextureWrapMode.Clamp,
                colorFormat: GraphicsFormat.R16G16B16A16_SFloat,
                // colorFormat: GraphicsFormat.R32G32B32A32_SFloat,
                name: "_SkyViewLut"
            );
            aerialPerspectiveLut ??= RTHandles.Alloc(
                AerialPerspectiveLutSize, AerialPerspectiveLutSize, AerialPerspectiveLutSize,
                dimension:TextureDimension.Tex3D,
                enableRandomWrite: true,
                filterMode:FilterMode.Bilinear,
                wrapMode:TextureWrapMode.Clamp,
                colorFormat:GraphicsFormat.R16G16B16A16_SFloat,
                name: "_AerialPerspectiveLut"
            );
        }

        /// <summary>
        /// Build the GPU constant buffer by reading parameters from SkyAtmosphere.Instance.
        /// </summary>
        private SkyAtmosphereBuffer BuildSkyAtmosphereBuffer(Vector3 sunAngle, float cameraY)
        {
            var sky = SkyAtmosphere.Instance;
            return new SkyAtmosphereBuffer
            {
                atmospherePositionPacked = new Vector4(sky.bottom, sky.top, cameraY / 1000 /* km */, sky.sunPower),
                sunParameterPacked = new Vector4(sunAngle.x, sunAngle.y, sunAngle.z, sky.sunAngularRadius),
                densityProfilePacked = new Vector4(1.0f / sky.rayleighScaleHeight, 1.0f / sky.mieScaleHeight,
                    sky.ozoneCenter, sky.ozoneHalfWidth),
                rayleighScattering = new Vector4(
                    sky.rayleighScattering.x * sky.rayleighMultiplier, 
                    sky.rayleighScattering.y * sky.rayleighMultiplier,
                    sky.rayleighScattering.z * sky.rayleighMultiplier, 1.0f),
                mieScatteringPacked = new Vector4(
                    sky.mieScattering.x * sky.mieMultiplier, 
                    sky.mieScattering.y * sky.mieMultiplier,
                    sky.mieScattering.z * sky.mieMultiplier, sky.miePhaseFunctionG),
                mieAbsorption = sky.mieAbsorption * sky.mieMultiplier,
                ozoneAbsorption = sky.ozoneAbsorption,
                groundAlbedo = sky.groundAlbedo
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

        private class AerialPerspectiveLutPassData
        {
            public ComputeShader shader;
            public int kernel;

            public TextureHandle transmittanceLut;
            public TextureHandle multiScatteringLut;
            public BufferHandle skyAtmosphereParameters;
            public TextureHandle aerialPerspectiveLut;
            public Matrix4x4 inverseViewProjMat;
            public Vector4 cameraPosition;

            public int groupX, groupY, groupZ;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            // Skip rendering if no SkyAtmosphere singleton exists
            if (SkyAtmosphere.Instance == null)
                return;


            var sky = SkyAtmosphere.Instance;
            var cameraData = frameData.Get<UniversalCameraData>();
            if (cameraData.cameraType == CameraType.Reflection)
            {
                return;
            }


            // 1. Update Atmosphere Buffer
            EnsureResources();
            var camera = cameraData.camera;


            // Read the sun direction directly from the Light transform on
            // SkyAtmosphere, rather than from URP's visibleLights list.
            // URP excludes lights with intensity == 0 from visibleLights,
            // which would cause sunDirection to fall back to Vector3.up (noon)
            // whenever SunLightUpdater sets the intensity to 0.
            Vector3 sunDirection = sky.sun != null
                ? -sky.sun.transform.forward
                : Vector3.up;

            var data = BuildSkyAtmosphereBuffer(sunDirection, Math.Max(0, camera.transform.position.y));
            skyAtmosphereParametersBuffer.SetData(new[] { data });

            // 2. Import Resources
            var parameterHandle = renderGraph.ImportBuffer(skyAtmosphereParametersBuffer);
            var transmittanceLutHandle = renderGraph.ImportTexture(transmittanceLut);
            var multiScatteringLutHandle = renderGraph.ImportTexture(multiScatteringLut);
            var skyViewLutHandle = renderGraph.ImportTexture(skyViewLut);
            var aerialPerspectiveLuteHandle = renderGraph.ImportTexture(aerialPerspectiveLut);

            // 3 & 4. Transmittance LUT + Multi-Scattering LUT
            // These only depend on the atmosphere's optical properties (not sun direction
            // or camera position), so we skip them when the atmosphere parameters have
            // not changed since the last frame.
            bool needAtmosphereLuts = sky.AtmosphereParamsDirty;
            // if (needAtmosphereLuts)
            {
                // 3. Build TransmittanceLUTGen Pass
                using (var builder =
                       renderGraph.AddComputePass<TransmittanceLutPassData>("TransmittanceLutGen", out var passData))
                {
                    // 3.1. Declare Used Resources
                    builder.UseTexture(transmittanceLutHandle, AccessFlags.Write);
                    builder.UseBuffer(parameterHandle, AccessFlags.Read);

                    // 3.2. Prepare Pass Data
                    passData.shader = computeShader;
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
                    passData.shader = computeShader;
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

                // Consume the dirty flag now that both LUTs have been scheduled for recompute
                sky.ClearDirty();
            }

            // 4.5  Async-read one texel from the TransmittanceLUT to drive
            //      directional light colour / intensity on the CPU.
            SunLightUpdater.RequestReadback(transmittanceLut.rt, sunDirection, Mathf.Max(0, camera.transform.position.y));

            // 5. Build Sky-View Lut Pass
            using (var builder = renderGraph.AddComputePass<SkyViewLutPassData>("SkyViewLutGen", out var passData))
            {
                // 5.1. Declare Used Resources
                builder.UseTexture(transmittanceLutHandle, AccessFlags.Read);
                builder.UseTexture(multiScatteringLutHandle, AccessFlags.Read);
                builder.UseTexture(skyViewLutHandle, AccessFlags.Write);
                builder.AllowGlobalStateModification(true);

                // 5.2 Prepare Pass Data
                passData.shader = computeShader;
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

                    ctx.cmd.SetGlobalTexture("_SkyViewLut", data.skyViewLut);
                    ctx.cmd.SetGlobalTexture("_TransmittanceLut", data.transmittanceLut);
                    ctx.cmd.SetGlobalBuffer("_SkyAtmosphereParametersBuffer", data.skyAtmosphereParameters);
                });
            }

            // 6. Build AerialPerspectiveLut Pass
            using (var builder = renderGraph.AddComputePass<AerialPerspectiveLutPassData>("AerialPerspectiveLutGen", out var passData))
            {
                // 6.1 Declare Used Resources
                builder.UseTexture(transmittanceLutHandle, AccessFlags.Read);
                builder.UseTexture(multiScatteringLutHandle, AccessFlags.Read);
                builder.UseTexture(aerialPerspectiveLuteHandle, AccessFlags.Write);
                builder.UseBuffer(parameterHandle, AccessFlags.Read);
                builder.AllowGlobalStateModification(true);

                // 6.2 Prepare Pass Data
                passData.shader = computeShader;
                passData.kernel =  passData.shader.FindKernel("kComputeAerialPerspectiveLut");
                passData.skyAtmosphereParameters = parameterHandle;
                passData.transmittanceLut =  transmittanceLutHandle;
                passData.multiScatteringLut = multiScatteringLutHandle;
                passData.aerialPerspectiveLut = aerialPerspectiveLuteHandle;
                passData.groupX = (AerialPerspectiveLutSize + 7) / 8;
                passData.groupY = (AerialPerspectiveLutSize + 7) / 8;
                passData.groupZ = (AerialPerspectiveLutSize + 7) / 8;

                var viewProjMatrix = GL.GetGPUProjectionMatrix(camera.projectionMatrix, false) * camera.worldToCameraMatrix;
                passData.inverseViewProjMat = viewProjMatrix.inverse;
                passData.cameraPosition = camera.transform.position;

                // 6.3 Set RenderFunc
                builder.SetRenderFunc(static (AerialPerspectiveLutPassData data, ComputeGraphContext ctx) =>
                {
                    ctx.cmd.SetComputeBufferParam(data.shader, data.kernel, "_SkyAtmosphereParametersBuffer", data.skyAtmosphereParameters);
                    ctx.cmd.SetComputeTextureParam(data.shader, data.kernel, "_TransmittanceLut", data.transmittanceLut);
                    ctx.cmd.SetComputeTextureParam(data.shader, data.kernel, "_MultiScatteringLut", data.multiScatteringLut);
                    ctx.cmd.SetComputeTextureParam(data.shader, data.kernel, "_AerialPerspectiveLutUAV", data.aerialPerspectiveLut);
                    ctx.cmd.SetComputeMatrixParam(data.shader,  "_InverseViewProjMatrix", data.inverseViewProjMat);
                    ctx.cmd.SetComputeVectorParam(data.shader, "_CameraPosition", data.cameraPosition);
                    ctx.cmd.DispatchCompute(data.shader, data.kernel, data.groupX, data.groupY, data.groupZ);
                    ctx.cmd.SetGlobalTexture("_AerialPerspectiveLut",  data.aerialPerspectiveLut);
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
